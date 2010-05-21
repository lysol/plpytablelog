/*

    logging.configure.sql

    This is a sort of least-common-denominator configuration
    file for logging setup.

    NOTE
    The modified_by_field is very optional.  The trigger function will attempt
    to figure out which field this, using modifiedby, then usermodified, then
    nothing.

*/
CREATE OR REPLACE FUNCTION logging.build_setup() RETURNS VOID AS $$
plpy.notice("Rebuilding the data for the setup table.")
plpy.execute("TRUNCATE TABLE logging.setup;")

setups = [
    ['public', 'lyvehicle', 'ly', ""],
    ['public', 'lystock', 'ly', ""],
    ['public', 'lydeal', 'ly', ""],
    ['public', 'lycustomer', 'ly', ""],
    ['public', 'lysalespay', 'ly', ""],
    ['public', 'slro', 'sl', ""],
    ['public', 'slrojobs', 'sl', ""],
    ['public', 'slroparts', 'sl', ""],
    ['public', 'slrotechs', 'sl', ""],
    ['public', 'slempmaster', 'sl', ""],
    ['public', 'scschedule', 'sl', ""],
    ['public', 'scjobs', 'sl', ""],
    ['public', 'scappt', 'sl', ""],
    ['public', 'scloaner', 'sl', ""],
    ['public', 'scloanerrecord', 'sl', ""],
    ['public', 'slctparts', 'sl', ""],
    ['public', 'slct', 'sl', ""],
    ['public', 'slpo', 'sl', ""],
    ['public', 'slpoparts', 'sl', ""],
    ['public', 'slparts', 'sl', ""],
    ['public', 'acchart', 'ac', ""],
    ['public', 'acglheader', 'ac', ""],
    ['public', 'acapinvoice', 'ac', ""],
    ['public', 'acarinvoice', 'ac', ""],
    ['public', 'accheck', 'ac', ""],
    ['public', 'slsetup', 'sl', ""],
    ['public', 'slpartstoorder', 'sl', ""],
    ['public', 'sllookup', 'sl', ""],
    ['public', 'sllookupparts', 'sl', ""],
    ]

plan = plpy.prepare("""
    INSERT INTO logging.setup
        (schema_name, table_name, log_table, modified_by_field)
        VALUES
        ($1, $2, $3, $4)
    """, ['text', 'text', 'text', 'text'])

for setup in setups:
    plpy.execute(plan, setup)

$$ LANGUAGE plpythonu VOLATILE;

SELECT logging.build_setup();
SELECT logging.deploy();
