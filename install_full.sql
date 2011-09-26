
            CREATE OR REPLACE FUNCTION logging_install() RETURNS VOID AS $INSTALL$
                BEGIN
                IF (
                    SELECT 'logging' IN (
                        SELECT nspname
                        FROM pg_catalog.pg_namespace
                        )
                   ) THEN RETURN;
                END IF;
                --BEGIN
        /*
 *
 *  logging.base_install.sql
 *
 *  Main install script for our PostgreSQL logging system.
 *  Only execute this if the database has never had the logging setup performed.
 *
 *  This file is psql-compatible.  It will not work with PGAdmin.
 *
 *
 */

/*

    Logging system schema setup.  You shouldn't ever have to
    execute this on its own.

    ~ DRA
*/

CREATE SCHEMA logging;
COMMENT ON SCHEMA logging IS 'Version 1.1: Logging schema containts setup, deployment, and storage for logging on table objects.';
CREATE TABLE logging.setup (
    schema_name varchar not null
    ,table_name varchar not null
    ,log_table varchar not null
    ,modified_by_field varchar not null default ''
    ,"timestamp" timestamp without time zone default now() not null
    ,exclude_events character varying[] CHECK (exclude_events <@ ARRAY['INSERT', 'DELETE', 'UPDATE']::character varying[])
    ,exclude_columns character varying[] DEFAULT ARRAY[]::character varying[]
);
CREATE UNIQUE INDEX logging_setup_idx ON logging.setup (schema_name, table_name);

COMMENT ON TABLE logging.setup IS 'Setup table for logging system.  To alter which tables are being logged, add a record to this table and execute logging.deploy().';
CREATE SEQUENCE logging.query_id_seq;
COMMENT ON SEQUENCE logging.query_id_seq IS 'All query_id values for all logging tables are pulled from this sequence.';
/*

    logging.functions.sql

    All logging-related functions should be installed in the logging schema.
    If you create a new one, place it in this file.


*/

CREATE OR REPLACE FUNCTION logging.deploy() RETURNS boolean AS $$

#
#   logging.deploy()
#
#   This function inspects the logging.setup table, creates any
#   logging tables and indexes as needed, and finally,
#   installs the triggers to perform the logging itself.
#

def pglist(instring):
    return instring[1:-1].split(',')

setup_records = plpy.execute("""
    SELECT schema_name, table_name, log_table, modified_by_field, exclude_events
    FROM logging.setup
""")

for row in setup_records:

    plpy.notice("""Managing triggers for "%s"."%s" """ % (row['schema_name'],
        row['table_name'])) 
    consistency_query = """
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = '%s'
        AND table_name = '%s'
    """ % (row['schema_name'], row['table_name'])

    if len(row['modified_by_field']) > 0:
        consistency_query = "%s %s" % (consistency_query,
            "AND column_name = '%s'" % row['modified_by_field'])
        

    num_rows = len(plpy.execute(consistency_query))
    if num_rows == 0:
        plpy.warning("%s.%s does not exist in information_schema.columns." % \
            (row['schema_name'], row['table_name']))
        continue

    plpy.execute("DROP TRIGGER IF EXISTS zzzlog_%s ON %s.%s" % \
        (row['table_name'], row['schema_name'], row['table_name']))
    
    trigger_args = [row['log_table']]
    
    if row['modified_by_field'] != None and row['modified_by_field'] != '':
        trigger_args.append(row['modified_by_field'])
    arg_string = ','.join(trigger_args)
    
    if row['exclude_events'] is None:
        before = 'INSERT OR UPDATE OR DELETE'
    else:
        events = pglist(row['exclude_events'])
        events = filter(lambda e: e not in events, ['INSERT', 'UPDATE', 'DELETE'])
        before = ' OR '.join(events)

    plpy.execute("""
        CREATE TRIGGER zzzlog_%s
        BEFORE %s ON %s.%s
        FOR EACH ROW
        EXECUTE PROCEDURE logging.modified(%s)
    """ % (row['table_name'], before, row['schema_name'], row['table_name'],
        arg_string))

# Now, create the logging tables if they do not exist.

log_tables = [row['log_table'] for row in \
    plpy.execute("SELECT DISTINCT log_table FROM logging.setup")]
schema_tables = [row['table_name'] for row in \
    plpy.execute("SELECT table_name FROM information_schema.columns WHERE " + \
    " table_schema = 'logging'")]

indexes = [row['indexname'] for row in plpy.execute("SELECT indexname FROM" + \
    " pg_catalog.pg_indexes WHERE schemaname = 'logging'")]

# Add a column here if you want to change indexes.  Simply add it here, then
# PERFORM logging.deploy();
index_columns = ('query_id', 'record_seq', 'column_name', 'event')

for log_table in log_tables:
    if log_table not in schema_tables:
        # Create logging table
        plpy.notice("""Creating logging table "%s" """ % log_table) 
        plpy.execute("""
            CREATE TABLE "logging"."%s" (
              seq serial
                NOT NULL,
              column_name character varying,
              old_value character varying,
              new_value character varying,
              modified_by character varying,
              client_addr inet,
              query_id integer
                NOT NULL,
              date_modified timestamp without time zone
                NOT NULL default now(),
              record_seq integer
                NOT NULL,
              schema_name character varying,
              table_name character varying,
              event character varying
                NOT NULL
                DEFAULT 'UNKNOWN'::character varying
            );
        """ % log_table)
    else:
        plpy.notice("""Table already created for "logging"."%s".""" \
            % log_table)
    
    for column_name in index_columns:
        if 'logging_%s_%s_idx' % (log_table, column_name) not in indexes:            
            plpy.notice("""Creating index for "%s"."%s" """ % (log_table, 
                column_name))
            plpy.execute("""
                CREATE INDEX "logging_%s_%s_idx"
                ON "logging"."%s"
                USING BTREE ("%s")
            """ % (log_table, column_name, log_table, column_name))
        else:
            plpy.notice("""Index "logging_%s_%s_idx" already created.""" % \
                (log_table, column_name))
        
# update view for viewing all logs
plpy.notice("Recreating all_logs view.")
plpy.execute("""
    DROP VIEW IF EXISTS logging.all_logs;
""")
        
view_sql = "CREATE VIEW logging.all_logs AS %s" % ' UNION ALL '.join(
    ["""SELECT '%s'::varchar as log_table,* FROM logging."%s" """ % \
        (log_table, log_table) for log_table in log_tables]
)
plpy.execute(view_sql)

plpy.notice("Autodocumenting logging tables.")
for log_table in log_tables:
    result = plpy.execute("SELECT schema_name,table_name " + \
        "FROM logging.setup WHERE log_table = '%s'" % log_table)
    source_tables = []
    for row in result:
        source_tables.append('"%s"."%s"' % (row['schema_name'], 
            row['table_name']))
    log_table_list = ','.join(source_tables)
    comment_sql = """
        COMMENT ON TABLE logging."%s"
        IS 'Destination for logged changes on the following tables: %s';
        """ % (log_table, log_table_list)
    plpy.execute(comment_sql)

return True

$$ LANGUAGE plpythonu VOLATILE;

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
CREATE OR REPLACE FUNCTION logging.size() RETURNS integer AS $$

/*
    logging.size()
    
    Returns the size, in bytes, of all log tables combined.
    
    ~ DRA
*/


DECLARE 
    v_size_bucket INTEGER DEFAULT 0;
    m_row RECORD;
BEGIN
    FOR m_row IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'logging'
    LOOP
        v_size_bucket = v_size_bucket + pg_relation_size('logging.' || m_row.table_name);
    END LOOP;
RETURN v_size_bucket;
END;

$$ LANGUAGE plpgsql VOLATILE;
CREATE OR REPLACE FUNCTION logging.reconstruct_query(query_id integer) RETURNS varchar AS $$

#
#   logging.reconstruct_query()
#
#   What this function does is attempt to return a query string that would 
#   reproduce the results from making the same changes that the log entry recorded.
#     
#   ~ DRA
# 

def get_quoted(value, quotebool):
    #plpy.notice('Quoted')
    if quotebool:
        return "'%s'" % value
    else:
        return value

def build_insert(results):
    #plpy.notice('Build Insert')
    table_name = results[0]['table_name']
    schema_name = results[0]['schema_name']
    column_names = [result['column_name'] for result in results]
    values = [result['new_value'] for result in results]
    data_types = get_quote_map(table_name, column_names)
    column_clause = '(%s)' % '","'.join(column_names)
    value_clause = '(%s)' % ','.join(map(lambda x: get_quoted(x['new_value'],
        data_types[x['column_name']], results)))

    insert_query = 'INSERT INTO "%s"."%s" %s VALUES %s' % \
        (schema_name, table_name, column_clause, value_clause)
    return insert_query

def build_delete(results):
    #plpy.notice('Build Delete')
    schema_name = results[0]['schema_name']
    table_name = results[0]['table_name']
    record_seq = results[0]['record_seq']
    
    return 'DELETE FROM "%s"."%s" WHERE seq = %i' % \
        (schema_name, table_name, record_seq)

def get_quote_map(table_name, column_names):
    #plpy.notice('Get Quote Map')
    data_types = {}
    for row in plpy.execute("""
        SELECT column_name,data_type
        FROM information_schema.columns
        WHERE table_name = '%s'
        AND column_name IN (%s)
    """ % (table_name, ','.join(["'%s'" % \
        column_name for column_name in column_names]))):
        #data_types[row['column_name']] = row['data_type']
        if row['data_type'] in ('double precision', 'money', 'bigint', 
            'smallint', 'boolean', 'integer', 'numeric', 'float', 'serial',
            'bigserial', 'real', 'decimal'):
            data_types[row['column_name']] = False
        else:
            data_types[row['column_name']] = True
    return data_types
    


def build_set_def(column_name, data_types, value):
    #plpy.notice('Build Set Def')
    if data_types[column_name] is True:
        return "\"%s\" = '%s'" % (column_name, value)
    else:
        return "\"%s\" = %s" % (column_name, value)

def build_update(results):
    #plpy.notice('Build Update')
    table_name = results[0]['table_name']
    record_seq = results[0]['record_seq']
    schema_name = results[0]['schema_name']
    column_names = [result['column_name'] for result in results]
    data_types = get_quote_map(table_name, column_names)
    set_clause = ' AND '.join([
        build_set_def(result['column_name'], data_types, result['new_value'])
        for result in results
    ])
    query = """
        UPDATE "%s"."%s" SET %s WHERE seq = %i
    """ % (schema_name, table_name, set_clause, record_seq)
    query = query.strip()
    return query

#plpy.notice('Beginning')

results = plpy.execute("""
    SELECT schema_name, table_name, event, column_name,
        old_value, new_value, record_seq
    FROM logging.all_logs
    WHERE query_id = %i
""" % query_id)

if len(results) == 0:
    plpy.error('No log entry for that query ID.')

event = results[0]['event']

if event == 'UPDATE':

    return build_update(results)

elif event == 'DELETE':
    
    return build_delete(results)
    


$$ LANGUAGE plpythonu STABLE;
CREATE OR REPLACE FUNCTION logging.prune() RETURNS boolean AS $$

#
#   logging.prune()
#
#   This function is designed to be called nightly.  We should only
#   need a month of changes at any time, and these logs get large quickly
#   depending on which table is logged.  This will delete any records older
#   than a month.
#
#   ~ DRA
#

for row in plpy.execute("SELECT DISTINCT log_table FROM logging.setup"):
    plpy.notice("Pruning logging.%s" % row['log_table'])
    plpy.execute("""
        DELETE FROM logging."%s"
        WHERE date_modified < NOW() - '1 year'::interval
    """ % row['log_table'])

return True

$$ LANGUAGE plpythonu VOLATILE;
DROP TYPE IF EXISTS log_record CASCADE;
CREATE TYPE log_record AS (
              seq integer,
              column_name character varying,
              column_value character varying,
              modified_by character varying,
              client_addr inet,
              query_id integer,
              date_modified timestamp without time zone,
              record_seq integer,
              schema_name character varying,
              table_name character varying,
              event character varying
);

CREATE OR REPLACE FUNCTION logging.original_record (log_table varchar, log_seq integer) RETURNS setof log_record AS $$

return_results = []
column_values = {}

log_plan = plpy.prepare("""
    SELECT schema_name, table_name, record_seq, modified_by, client_addr,
        query_id, date_modified
    FROM logging.all_logs
    WHERE log_table = $1
    AND seq = $2
""", ["text", "int4"])

results = plpy.execute(log_plan, [log_table, log_seq])

record_seq = results[0]['record_seq']
schema_name = results[0]['schema_name']
table_name = results[0]['table_name']
modified_by = results[0]['modified_by']
client_addr = results[0]['client_addr']
query_id = results[0]['query_id']
date_modified = results[0]['date_modified']

first_change_query = """
    SELECT * FROM logging.sl
    WHERE ROW(query_id, column_name)
        IN (
            SELECT  min(query_id) ,column_name
            FROM logging.sl
            GROUP BY schema_name, table_name, record_seq, column_name
            HAVING schema_name = $1 AND table_name = $2 
                AND record_seq = $3
            ORDER BY column_name, min(query_id)
           )
    ORDER BY column_name, query_id;
"""

current_row_query = """
    SELECT * FROM "%s"."%s"
    WHERE seq = $1
""" % (schema_name, table_name)

current_plan = plpy.prepare(current_row_query, ["int4"])
first_change_plan = plpy.prepare(first_change_query,
    ["text", "text", "int4"])
current_row = plpy.execute(current_plan, [record_seq])
first_change = plpy.execute(first_change_plan,
    [schema_name, table_name, record_seq])

for row in filter(lambda x: x['column_name'] != '', first_change):
    column_values[row['column_name']] = row['old_value']

columns = current_row[0].keys()
for column in filter(lambda x: x not in column_values.keys(), columns):
    column_values[column] = current_row[0][column]

# Build the resulting rows.

for column_name, column_value in column_values.iteritems():
    return_results.append({
        'seq': log_seq,
        'column_name': column_name,
        'column_value': column_value,
        'modified_by': modified_by,
        'client_addr': client_addr,
        'query_id': query_id,
        'date_modified': date_modified,
        'record_seq': record_seq,
        'schema_name': schema_name,
        'table_name': table_name,
        'event': 'INSERT'
    })

return return_results

$$ LANGUAGE plpythonu STABLE;


-- Second version of the function that can take other arguments to reach the
-- original record values.

CREATE OR REPLACE FUNCTION logging.original_record(log_table character varying, original_table character varying, in_record_seq integer)
 RETURNS SETOF log_record
 LANGUAGE plpythonu
 STABLE
AS $function$

            return_results = []
            column_values = {}

            log_plan = plpy.prepare("""
                SELECT schema_name, table_name, record_seq, modified_by, client_addr,
                    query_id, date_modified
                FROM logging.all_logs
                WHERE log_table = $1
                AND table_name = $2
                AND record_seq = $3
            """, ["text", "text", "int4"])

            results = plpy.execute(log_plan, [log_table, original_table, in_record_seq])
            if len(results) == 0:
                return []
            record_seq = results[0]['record_seq']
            schema_name = results[0]['schema_name']
            table_name = results[0]['table_name']
            modified_by = results[0]['modified_by']
            client_addr = results[0]['client_addr']
            query_id = results[0]['query_id']
            date_modified = results[0]['date_modified']

            first_change_query = """
                SELECT * FROM logging.sl
                WHERE ROW(query_id, column_name)
                    IN (
                        SELECT  min(query_id) ,column_name
                        FROM logging.sl
                        GROUP BY schema_name, table_name, record_seq, column_name
                        HAVING schema_name = $1 AND table_name = $2 
                            AND record_seq = $3
                        ORDER BY column_name, min(query_id)
                       )
                ORDER BY column_name, query_id;
            """

            current_row_query = """
                SELECT * FROM "%s"."%s"
                WHERE seq = $1
            """ % (schema_name, table_name)

            current_plan = plpy.prepare(current_row_query, ["int4"])
            first_change_plan = plpy.prepare(first_change_query,
                ["text", "text", "int4"])
            current_row = plpy.execute(current_plan, [record_seq])
            first_change = plpy.execute(first_change_plan,
                [schema_name, table_name, record_seq])

            for row in filter(lambda x: x['column_name'] != '', first_change):
                column_values[row['column_name']] = row['old_value']

            columns = current_row[0].keys()
            for column in filter(lambda x: x not in column_values.keys(), columns):
                column_values[column] = current_row[0][column]

            # Build the resulting rows.

            for column_name, column_value in column_values.iteritems():
                return_results.append({
                    'seq': 0,
                    'column_name': column_name,
                    'column_value': column_value,
                    'modified_by': modified_by,
                    'client_addr': client_addr,
                    'query_id': query_id,
                    'date_modified': date_modified,
                    'record_seq': record_seq,
                    'schema_name': schema_name,
                    'table_name': table_name,
                    'event': 'INSERT'
                })

            return return_results

            $function$
;
CREATE OR REPLACE FUNCTION logging.get_record(log_table character varying, log_seq integer)
 RETURNS SETOF log_record
AS $function$
"""
logging.get_record

"""
return_results = []
columns_processed = []

# Base GD key for storing plans for this log_table.
base_key = "logging_%s" % log_table

# Handle log_plan
log_plan_key = "%s_log_plan" % base_key
if GD.has_key(log_plan_key):
    log_plan = GD[log_plan_key]
else:
    log_plan = plpy.prepare("""
        SELECT schema_name, table_name, record_seq, modified_by, client_addr,
            query_id, date_modified, (
                SELECT event
                FROM logging."%s" b
                WHERE a.record_seq = b.record_seq
                ORDER BY seq DESC
                LIMIT 1
                ) as last_event
        FROM logging."%s" a
        WHERE seq = $1
        """ % (log_table, log_table), ["int4"])
    GD[log_plan_key] = log_plan

results = plpy.execute(log_plan, [log_seq])

if len(results) != 1:
    plpy.error("No log entry was found with that sequence number.")

record_seq = results[0]['record_seq']
schema_name = results[0]['schema_name']
table_name = results[0]['table_name']
modified_by = results[0]['modified_by']
client_addr = results[0]['client_addr']
query_id = results[0]['query_id']
date_modified = results[0]['date_modified']
last_event = results[0]['last_event']

# Handle the last_change_plan
last_change_plan_key = "%s_last_change_plan" % base_key
if GD.has_key(last_change_plan_key):
    last_change_plan = GD[last_change_plan_key]
else:
    last_change_query = """
        SELECT * FROM logging."%s"
        WHERE ROW(query_id, column_name)
            IN (
                SELECT  max(query_id) ,column_name
                FROM logging."%s"
                WHERE query_id <= $4
                GROUP BY schema_name, table_name, record_seq, column_name
                HAVING schema_name = $1 AND table_name = $2 
                    AND record_seq = $3
                ORDER BY column_name, min(query_id)
               )
        ORDER BY column_name, query_id;
    """ % (log_table, log_table)
    last_change_plan = plpy.prepare(last_change_query,
        ["text", "text", "int4", "int4"])
    GD[last_change_plan_key] = last_change_plan

last_change = plpy.execute(last_change_plan,
    [schema_name, table_name, record_seq, query_id])

for row in filter(lambda x: x['column_name'] != '', last_change):
    return_results.append({
        'seq': row['seq'],
        'column_name': row['column_name'],
        'column_value': row['new_value'],
        'modified_by': row['modified_by'],
        'client_addr': row['client_addr'],
        'query_id': row['query_id'],
        'date_modified': row['date_modified'],
        'record_seq': row['record_seq'],
        'schema_name': row['schema_name'],
        'table_name': row['table_name'],
        'event': row['event']
    })

    columns_processed.append(row['column_name'])

# Handle is_deleted_plan
#deleted_plan_key = "%s_deleted_plan" % base_key 
#if GD.has_key(deleted_plan_key):
#    is_deleted_plan = GD[deleted_plan_key]
#else:
#    is_deleted_query = """
#        SELECT event
#        FROM logging."%s"
#        WHERE record_seq = $1
#        ORDER BY seq DESC
#        LIMIT 1
#        """ % (log_table, log_table)
#    is_deleted_plan = plpy.prepare(is_deleted_query, ["int4"])
#    GD[deleted_plan_key] = is_deleted_plan
#
#event = plpy.execute(is_deleted_plan, [record_seq])[0]['event']
if last_event == 'DELETE':
    # Record was deleted. We will grab values from the DELETE record.

    # Handle final_change_plan
    final_change_plan_key = "%s_final_change_plan" % base_key
    if GD.has_key(final_change_plan_key):
        final_change_plan = GD[final_change_plan_key]
    else:
        final_change_query = """
            SELECT * FROM logging."%s"
            WHERE ROW(query_id, column_name)
                IN (
                    SELECT max(query_id) ,column_name
                    FROM logging."%s"
                    WHERE event = 'DELETE'
                    GROUP BY schema_name, table_name, record_seq, column_name
                    HAVING schema_name = $1 AND table_name = $2
                        AND record_seq = $3
                   )
            ORDER BY column_name, query_id;
            """ % (log_table, log_table)
        final_change_plan = plpy.prepare(final_change_query,
            ["text", "text", "int4"])
        GD[final_change_plan_key] = final_change_plan

    final_changes = plpy.execute(final_change_plan,
        [schema_name, table_name, record_seq])

    for row in filter(lambda x: x['column_name'] not in \
        columns_processed, final_changes):
        # Add it here
        return_results.append({
            'seq': row['seq'],
            'column_name': row['column_name'],
            'column_value': row['old_value'],
            'modified_by': row['modified_by'],
            'client_addr': row['client_addr'],
            'query_id': row['query_id'],
            'date_modified': row['date_modified'],
            'record_seq': row['record_seq'],
            'schema_name': row['schema_name'],
            'table_name': row['table_name'],
            'event': row['event']
        })

else:
    # Record still exists. Pull values from that instead.

    current_row_query = """
        SELECT * FROM "%s"."%s"
        WHERE seq = $1
        LIMIT 1
    """ % (schema_name, table_name)
    current_plan = plpy.prepare(current_row_query, ["int4"])
    current_row = plpy.execute(current_plan, [record_seq])

    columns = current_row[0].keys()
    for column in filter(lambda x: x not in columns_processed, columns):
        return_results.append({
            'seq': log_seq,
            'column_name': column,
            'column_value': current_row[0][column],
            'modified_by': modified_by,
            'client_addr': client_addr,
            'query_id': query_id,
            'date_modified': None,
            'record_seq': record_seq,
            'schema_name': schema_name,
            'table_name': table_name,
            'event': 'INSERT'
        })

return return_results

$function$ LANGUAGE plpythonu STABLE;

                --EXCEPTION WHEN OTHERS THEN
                --    RETURN;
                --END;
                END;
                $INSTALL$ LANGUAGE plpgsql VOLATILE;
                SELECT logging_install();
        
