/*

    Logging system schema setup.  You shouldn't ever have to
    execute this on its own.

    ~ DRA
*/

CREATE SCHEMA logging;
COMMENT ON SCHEMA logging IS 'Logging schema containts setup, deployment, and storage for logging on table objects.';
CREATE TABLE logging.setup (
    schema_name varchar not null
    ,table_name varchar not null
    ,log_table varchar not null
    ,modified_by_field varchar not null default ''
    ,"timestamp" timestamp without time zone default now() not null
    ,exclude_events character varying[] CHECK (exclude_events <@ ARRAY['INSERT', 'DELETE', 'UPDATE']::character varying[])
);
COMMENT ON TABLE logging.setup IS 'Setup table for logging system.  To alter which tables are being logged, add a record to this table and execute logging.deploy().';
CREATE SEQUENCE logging.query_id_seq;
COMMENT ON SEQUENCE logging.query_id_seq IS 'All query_id values for all logging tables are pulled from this sequence.';
