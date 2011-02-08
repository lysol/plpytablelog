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
TRUNCATE TABLE logging.setup;
INSERT INTO logging.setup
    (schema_name, table_name, log_table, modified_by_field, exclude_events,
        exclude_columns)
    VALUES
    ('public', 'lyvehicle', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lystock', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lybuy', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lyguest', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lylease', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lydeal', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lycustomer', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lysalespay', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slmatrixlists', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slpartsdiscountcodes', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slpartsource', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slvendor', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sltaxtable', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sltaxkey', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sllabormatrix', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slrohoursaudit', 'sl', '', ARRAY['INSERT'], ARRAY[]::character varying[]),
    ('public', 'slro', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slrojobs', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slroopcodes', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slrosublets', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slrorecomm', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slroparts', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slrotechs', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slempmaster', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scschedule', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scjobs', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scappt', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scloaner', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scloanerrecord', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slctparts', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slct', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slpo', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slpoparts', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slparts', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acchart', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acglheader', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acgroup', 'ac', '', ARRAY['INSERT'], ARRAY[]::character varying[]), 
    ('public', 'acar', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acap', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'actemplate', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acstringline', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acsetup', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acreceipts', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acapinvoice', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acarinvoice', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'accheck', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acapsetup', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acarsetup', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acchartidlinksetup', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acstatement', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'actemplate', 'ac', '', NULL, ARRAY[]::character varying[]),
    ('public', 'crreportsetup', 'cr', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lyfisetup', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'lysetup', 'ly', '', NULL, ARRAY[]::character varying[]),
    ('public', 'mcmiscentry', 'mc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'pyimportsetup', 'py', '', NULL, ARRAY[]::character varying[]),
    ('public', 'pypayimportsetup', 'py', '', NULL, ARRAY[]::character varying[]),
    ('public', 'pysetup', 'py', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scappt', 'sc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scjobs', 'sc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scadvisorsetup', 'sc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scbdeptsetup', 'sc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'scsetup', 'sc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sldispatchsetup', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slmfgsetup', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slsetup', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'slpartstoorder', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sllookup', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'sllookupparts', 'sl', '', NULL, ARRAY[]::character varying[]),
    ('public', 'pypersonneltimecard', 'py', '', NULL, ARRAY[]::character varying[]),
    ('public', 'acline', 'ac', '', ARRAY['INSERT'], ARRAY['postgl']::character varying[]),
    ('public', 'cmcommissions', 'cm', '', NULL, ARRAY[]::character varying[]),
    ('public', 'cmdealempcommissions', 'cm', '', NULL, ARRAY[]::character varying[]),
    ('public', 'cmcommissionemps', 'cm', '', NULL, ARRAY[]::character varying[]),
    ('public', 'cmcommissionroles', 'cm', '', NULL, ARRAY[]::character varying[]),
    ('public', 'mcmisccodes', 'mc', '', NULL, ARRAY[]::character varying[]),
    ('public', 'mcmiscentry', 'mc', '', NULL, ARRAY[]::character varying[])

$$ LANGUAGE SQL VOLATILE;

SELECT logging.build_setup();
SELECT logging.deploy();
