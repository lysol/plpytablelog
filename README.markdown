plpytablelog
============

plpytablelog is an easily maintained table logging system for PostgreSQL. It
removes the need for manual administration of triggers on individual tables,
instead wrapping maintenance of the tables, triggers, and indexes on the
logging tables into a single function which can be used to rebuild triggers on
the fly (save for some locks on tables while DDL is being changed).

The system supports excluding specific trigger events from the log, as well as
pruning tables based on a timeframe and size. (See `logging.prune.sql` and
`logging.prune_size.sql`)

There are a number of other functions included that may or may not work at
this time.  Included is an undelete function that will restore records from
logged `DELETE` events.

Consult the `INSTALL` file for installing to your database. 

The system also supports multiple table logs. See INSTALL for configuration of
these.

Nearly every component of the logging schema, once installed, has a comment
applied describing its purpose.
