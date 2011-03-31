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
