/*

    logging.functions.sql

    All logging-related functions should be installed in the logging schema.
    If you create a new one, place it in this file.


*/

\i ./src/functions/logging.deploy.sql
\i ./src/functions/logging.modified.sql
\i ./src/functions/logging.size.sql
\i ./src/functions/logging.reconstruct_query.sql
\i ./src/functions/logging.prune.sql
\i ./src/functions/logging.original_record.sql
\i ./src/functions/logging.get_record.sql
