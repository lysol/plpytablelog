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

\i ./src/logging.schema.sql
\i ./src/logging.functions.sql
