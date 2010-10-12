CREATE OR REPLACE FUNCTION logging.prune_size(max_log_size bigint) RETURNS boolean AS $$

#
#   logging.prune_size()
#
#   This function is designed to be run nightly. This function will check for a
#   logging.settings table and row to check for a maximum log table size. If
#   the calculation comes up with a number of rows to delete to meet the max
#   size, it'll delete that number of records.
#   ~ DRA
#

for row in plpy.execute("SELECT DISTINCT log_table FROM logging.setup"):
    # Cluster the table based on the query_id. This will also blow out
    # any bloat present for calculating the size of the table.
    plpy.execute("""
        CLUSTER logging_%(log_table)s_query_id_idx
        ON logging.%(log_table)s
        """ % ({
            'log_table': row['log_table']
            }))
    try:
        rows_to_prune = plpy.execute("""
            SELECT
                (pg_relation_size('logging.%(log_table)s') - %(max_log_size)s)
                /
                  (pg_relation_size('logging.%(log_table)s') / (
                    SELECT count(*) FROM logging.%(log_table)s)
                    )
                 as rows_to_prune
            """ % ({
                'log_table': row['log_table'],
                'max_log_size': max_log_size
                }))[0]['rows_to_prune']
    except plpy.SPIError:
        rows_to_prune = 0

    if rows_to_prune > 0:
        plpy.execute("""
            DELETE FROM logging."%(log_table)s"
            WHERE seq IN (
                SELECT seq FROM logging."%(log_table)s"
                ORDER BY seq ASC
                LIMIT %(rows_to_prune)s)
        """ % ({
            'log_table': row['log_table'],
            'rows_to_prune': rows_to_prune
            }))

return True

$$ LANGUAGE plpythonu VOLATILE;
