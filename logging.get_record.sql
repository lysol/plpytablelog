CREATE OR REPLACE FUNCTION logging.get_record(log_table character varying, log_seq integer)
 RETURNS SETOF log_record
AS $function$

return_results = []
columns_processed = []

log_plan = plpy.prepare("""
    SELECT schema_name, table_name, record_seq, modified_by, client_addr,
        query_id, date_modified
    FROM logging.all_logs
    WHERE log_table = $1
    AND seq = $2
""", ["text", "int4"])

results = plpy.execute(log_plan, [log_table, log_seq])

if len(results) != 1:
    plpy.error("No log entry was found with that sequence number.")

record_seq = results[0]['record_seq']
schema_name = results[0]['schema_name']
table_name = results[0]['table_name']
modified_by = results[0]['modified_by']
client_addr = results[0]['client_addr']
query_id = results[0]['query_id']
date_modified = results[0]['date_modified']

last_change_query = """
    SELECT * FROM logging.sl
    WHERE ROW(query_id, column_name)
        IN (
            SELECT  max(query_id) ,column_name
            FROM logging.sl
            WHERE query_id <= $4
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
last_change_plan = plpy.prepare(last_change_query,
    ["text", "text", "int4", "int4"])
current_row = plpy.execute(current_plan, [record_seq])
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
