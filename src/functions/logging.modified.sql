CREATE OR REPLACE FUNCTION logging.modified() RETURNS trigger AS $$
#
#  logging.modified
#
#  This is the central trigger function that is created by logging.deploy().
#  You should never have to manually add this to a trigger.  Instead,
#  add a record to logging.setup, and SELECT logging.deploy().
#
#  ~ DRA
#

from datetime import datetime

# First check if logging_disable is present (and temporary)

blocked = plpy.execute("""
    SELECT count(*) FROM information_schema.tables
    WHERE table_name = 'logging_disable'
    AND table_type = 'LOCAL TEMPORARY'
    """)[0]['count']

if blocked == 1:
    return


# Ask the kind sequence for our next ID.  All inserts on the same event will
# have the same query ID.
query_id = plpy.execute("""
    SELECT nextval('logging.query_id_seq') as query_id
""")[0]['query_id']

# Logging table is specified as the first argument.
logging_table = TD['args'][0]

# We use the same record for a few operations.
if TD['event'] == 'DELETE':
    record = 'old'
else:
    record = 'new'

# Determine if we can grab the modifiedby field.
modified_field = ''
if TD.has_key('args') and len(TD['args']) > 1:
    modified_field = TD[record][TD['args'][1]]
elif TD[record].has_key('createdby') and TD['event'] == 'INSERT':
    modified_field = TD[record]['createdby']
elif TD[record].has_key('usercreated') and TD['event'] == 'INSERT':
    modified_field = TD[record]['usercreated']
elif TD[record].has_key('modifiedby'):
    modified_field = TD[record]['modifiedby']
elif TD[record].has_key('usermodified'):
    modified_field = TD[record]['usermodified']

## finally, update the modified time on the original record.
if TD['event'] in ['UPDATE','INSERT'] and TD['new'].has_key('modified'):
    right_now = datetime.today().__str__()
    TD['new']['modified'] = right_now

    # In plpythonu we have to return a string with our status to determine if
    # the row has been modified.  In this case, MODIFY.  If we just want to
    # abort the event, return SKIP.  If TD["when"] == 'BEFORE' then return None
    # or OK to signify nothing was modified.
    action = 'MODIFY'
else:
    action = 'OK'

# prepare the log insert plan
log_plan = plpy.prepare("""
    INSERT INTO logging."%s" (
        "old_value", "new_value",
        "record_seq",
        "event", "schema_name", "table_name", "column_name",
        "query_id", "client_addr", "modified_by"
    )
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, CAST($9 AS inet), $10
    WHERE NOT (
        SELECT exclude_columns
        FROM logging.setup
        WHERE schema_name = $5
        AND table_name = $6
        ) @> ARRAY[$7]::character varying[]
""" % logging_table, ["text", "text", "int4", "text", "text", "text", "text",
    "int4", "text", "text"]
)

logged_delete = False
insert_done = False
values = []

# cycle through each column, check for changes.
# Also, check for seq

columns = TD[record].keys()
if 'seq' not in columns:
    record_seq = 0
else:
    record_seq = TD[record]['seq']

# Filter out timestamps. They are superfluous to us (the borg).
for column in filter(lambda x: x != 'modified', columns):

    # only insert if there is a change.
    if TD["event"] == 'UPDATE' and TD['old'][column] != TD['new'][column]:
        values = [
            str(TD['old'][column]),
            str(TD['new'][column]),
            record_seq,
        ]

    # only insert one record for a deletion
    elif TD['event'] == 'DELETE':

        values = [
            str(TD['old'][column]),
            '',
            record_seq,
        ]

    # insert all columns with an old value of 'OLD'
    elif TD['event'] == 'INSERT' and str(TD['new'][column]) != '' and \
        not insert_done:

        values = [
            '',
            '',
            record_seq,
        ]
        
        column = ''
        insert_done = True

    # Ahhh! Woooh! What's happening? Who am I? Why am I here? What's my purpose
    # in life? What do I mean by who am I?
    elif TD['event'] == 'UNKNOWN':
        return None

    # execute with extreme prejudice
    if len(values) > 0:
        try:
            values.extend([ TD['event'], TD['table_schema'], TD['table_name'],
                            column, query_id, plpy.execute("""
                                SELECT inet_client_addr()
                            """)[0]['inet_client_addr'], modified_field
            ])
            plpy.execute(log_plan, values)
        except:
            pass

return action
$$ LANGUAGE plpythonu VOLATILE;
