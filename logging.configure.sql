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
plpy.execute("TRUNCATE TABLE logging.setup;")

setups = [
    ['public', 'lyvehicle', 'ly', ""],
    ['public', 'lystock', 'ly', ""],
    ['public', 'lybuy', 'ly', ""],
    ['public', 'lylease', 'ly', ""],
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
    ['public', 'acar', 'ac', ""],
    ['public', 'acap', 'ac', ""],
    ['public', 'actemplate', 'ac', ""],
    ['public', 'acstringline', 'ac', ""],
    ['public', 'acsetup', 'ac', ""],
    ['public', 'acreceipts', 'ac', ""],
    ['public', 'acapinvoice', 'ac', ""],
    ['public', 'acarinvoice', 'ac', ""],
    ['public', 'accheck', 'ac', ""],
    ['public', 'acapsetup', 'ac', ""],
    ['public', 'acarsetup', 'ac', ""],
    ['public', 'acchartidlinksetup', 'ac', ""],
    ['public', 'acstatement', 'ac', ""],
    ['public', 'actemplate', 'ac', ""],
    ['public', 'crreportsetup', 'cr', ""],
    ['public', 'lyfisetup', 'ly', ""],
    ['public', 'lysetup', 'ly', ""],
    ['public', 'mcmiscentry', 'mc', ""],
    ['public', 'pyimportsetup', 'py', ""],
    ['public', 'pypayimportsetup', 'py', ""],
    ['public', 'pysetup', 'py', ""],
    ['public', 'scadvisorsetup', 'sc', ""],
    ['public', 'scbdeptsetup', 'sc', ""],
    ['public', 'scsetup', 'sc', ""],
    ['public', 'sldispatchsetup', 'sl', ""],
    ['public', 'slmfgsetup', 'sl', ""],
    ['public', 'slsetup', 'sl', ""],
    ['public', 'slpartstoorder', 'sl', ""],
    ['public', 'sllookup', 'sl', ""],
    ['public', 'sllookupparts', 'sl', ""],
    ['public', 'pypersonneltimecard', 'py', ""],
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
