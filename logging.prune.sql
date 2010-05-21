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
