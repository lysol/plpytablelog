CREATE OR REPLACE FUNCTION logging.deploy() RETURNS boolean AS $$

#
#   logging.deploy()
#
#   This function inspects the logging.setup table, creates any
#   logging tables and indexes as needed, and finally,
#   installs the triggers to perform the logging itself.
#
setup_records = plpy.execute("""
    SELECT schema_name, table_name, log_table, modified_by_field
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

    plpy.execute("DROP TRIGGER IF EXISTS log_%s ON %s.%s" % \
        (row['table_name'], row['schema_name'], row['table_name']))
    
    trigger_args = [row['log_table']]
    
    if row['modified_by_field'] != None and row['modified_by_field'] != '':
        trigger_args.append(row['modified_by_field'])
    arg_string = ','.join(trigger_args)
    
    plpy.execute("""
        CREATE TRIGGER log_%s
        BEFORE INSERT OR UPDATE OR DELETE ON %s.%s
        FOR EACH ROW
        EXECUTE PROCEDURE logging.modified(%s)
    """ % (row['table_name'], row['schema_name'], row['table_name'],
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
# SELECT logging.deploy();
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

