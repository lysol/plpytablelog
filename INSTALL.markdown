QUICK START
===========

Requirements: `psql` (or PGAdmin if using `install_full.sql`), python,
plpythonu, superuser access.

install.sql and `install_full.sql` accomplish the same goal of building the base
schema for installation and configuration. The former is suited for use with
`psql` and uses the `\i` command to include child files, while `install_full.sql` is
built using `build_deployable_install.py` and includes all files in the same
.sql file.

So, in short, if you're using PGAdmin III, use `install_full.sql`, if you're
using `psql`, use `install.sql`.

After this is run against your database, the logging schema will be present.
For the impatient, the following example would log the table `public.users` into
`logging.userlog` for all events.

    -- If you haven't already done so, create plpythonu.
    psql -h yourserver -c "CREATE LANGUAGE plpythonu;"
    psql -h yourserver -f install.sql
    psql -h yourserver
    > BEGIN;
    > INSERT INTO logging.setup (
          schema_name, table_name, log_table
      ) VALUES (
          'public', 'users', 'userlog'
      );
    > SELECT logging.deploy();
    > COMMIT;


CONFIGURATION
=============

The table structure is:

`schema_name`
-------------
The schema of the table to be logged.


`table_name`
------------
The table to be logged.


`log_table`
-----------
The table name to log changes to.
For example, a value of 'service' will create the table logging.service,
and if this table does not exist, logging.deploy() will create it.


`modified_by_field`
-------------------
User-defined token.
If you put a column name from the logged table in this field,
its new value (the 'after' record in the trigger) will be recorded. This is
technically redundant but may make forensics a little more efficient. Its
original intention is a user modified field for easily tracking
application-level actions by individual users.
This defaults to the hard-coded field name 'modifiedby'.


`exclude_events`
----------------
Exclude trigger events from the log.
In tables with many INSERTs and few UPDATEs, you may wish to restrict what
events are logged. If this field is NULL, all events are recorded. This is
a character varying array field.

`exclude_columns`
-----------------
Exclude specific columns from the log.
This is also a character varying array field.


Once you make changes to `logging.setup`, `SELECT logging.deploy()`. This function
generates the logging tables, indexes, and triggers on the tables in question.

This WILL alter DDL on each table logged, so plan accordingly (not during
production hours, if you have such a construct).

NOTES
=====

There is hard-coded behavior at this time to check for the column `seq`. This 
is the value that is saved to `record_seq`. This will change in the future to a
configurable column name or the first primary key column, but as of now
requires that you at the very least use a column named `seq` to satisfy
the trigger function.