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

plpy.notice(column_values)
columns = current_row[0].keys()
plpy.notice(columns)
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
