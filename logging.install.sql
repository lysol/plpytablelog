/*
 *
 *  logging.install.sql
 *
 *  Main install script for our PostgreSQL logging system.
 *  Only execute this if the database has never had the logging setup performed.
 *
 *  This file is psql-compatible.  It will not work with PGAdmin.
 *
 *
 */

\i /home/darnold/Development/logging_system/logging.schema.sql
\i /home/darnold/Development/logging_system/logging.functions.sql
\i /home/darnold/Development/logging_system/logging.configure.sql
--\i /home/darnold/Development/logging_system/logging.schedule_prune.sql
