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
    (schema_name, table_name, log_table, modified_by_field, exclude_events)
    VALUES
    ('public', 'lyvehicle', 'ly', '', NULL),
    ('public', 'lystock', 'ly', '', NULL),
    ('public', 'lybuy', 'ly', '', NULL),
    ('public', 'lylease', 'ly', '', NULL),
    ('public', 'lydeal', 'ly', '', NULL),
    ('public', 'lycustomer', 'ly', '', NULL),
    ('public', 'lysalespay', 'ly', '', NULL),
    ('public', 'slmatrixlists', 'sl', '', NULL),
    ('public', 'slpartsdiscountcodes', 'sl', '', NULL),
    ('public', 'slpartsource', 'sl', '', NULL),
    ('public', 'slvendor', 'sl', '', NULL),
    ('public', 'sltaxtable', 'sl', '', NULL),
    ('public', 'sltaxkey', 'sl', '', NULL),
    ('public', 'sllabormatrix', 'sl', '', NULL),
    ('public', 'slrohoursaudit', 'sl', '', ARRAY['INSERT']),
    ('public', 'slro', 'sl', '', NULL),
    ('public', 'slrojobs', 'sl', '', NULL),
    ('public', 'slroparts', 'sl', '', NULL),
    ('public', 'slrotechs', 'sl', '', NULL),
    ('public', 'slempmaster', 'sl', '', NULL),
    ('public', 'scschedule', 'sl', '', NULL),
    ('public', 'scjobs', 'sl', '', NULL),
    ('public', 'scappt', 'sl', '', NULL),
    ('public', 'scloaner', 'sl', '', NULL),
    ('public', 'scloanerrecord', 'sl', '', NULL),
    ('public', 'slctparts', 'sl', '', NULL),
    ('public', 'slct', 'sl', '', NULL),
    ('public', 'slpo', 'sl', '', NULL),
    ('public', 'slpoparts', 'sl', '', NULL),
    ('public', 'slparts', 'sl', '', NULL),
    ('public', 'acchart', 'ac', '', NULL),
    ('public', 'acglheader', 'ac', '', NULL),
    ('public', 'acar', 'ac', '', NULL),
    ('public', 'acap', 'ac', '', NULL),
    ('public', 'actemplate', 'ac', '', NULL),
    ('public', 'acstringline', 'ac', '', NULL),
    ('public', 'acsetup', 'ac', '', NULL),
    ('public', 'acreceipts', 'ac', '', NULL),
    ('public', 'acapinvoice', 'ac', '', NULL),
    ('public', 'acarinvoice', 'ac', '', NULL),
    ('public', 'accheck', 'ac', '', NULL),
    ('public', 'acapsetup', 'ac', '', NULL),
    ('public', 'acarsetup', 'ac', '', NULL),
    ('public', 'acchartidlinksetup', 'ac', '', NULL),
    ('public', 'acstatement', 'ac', '', NULL),
    ('public', 'actemplate', 'ac', '', NULL),
    ('public', 'crreportsetup', 'cr', '', NULL),
    ('public', 'lyfisetup', 'ly', '', NULL),
    ('public', 'lysetup', 'ly', '', NULL),
    ('public', 'mcmiscentry', 'mc', '', NULL),
    ('public', 'pyimportsetup', 'py', '', NULL),
    ('public', 'pypayimportsetup', 'py', '', NULL),
    ('public', 'pysetup', 'py', '', NULL),
    ('public', 'scappt', 'sc', '', NULL),
    ('public', 'scjobs', 'sc', '', NULL),
    ('public', 'scadvisorsetup', 'sc', '', NULL),
    ('public', 'scbdeptsetup', 'sc', '', NULL),
    ('public', 'scsetup', 'sc', '', NULL),
    ('public', 'sldispatchsetup', 'sl', '', NULL),
    ('public', 'slmfgsetup', 'sl', '', NULL),
    ('public', 'slsetup', 'sl', '', NULL),
    ('public', 'slpartstoorder', 'sl', '', NULL),
    ('public', 'sllookup', 'sl', '', NULL),
    ('public', 'sllookupparts', 'sl', '', NULL),
    ('public', 'pypersonneltimecard', 'py', '', NULL),
    ('public', 'acline', 'ac', '', ARRAY['INSERT']),
    ('public', 'cmcommissions', 'cm', '', NULL),
    ('public', 'cmdealempcommissions', 'cm', '', NULL),
    ('public', 'cmcommissionemps', 'cm', '', NULL),
    ('public', 'cmcommissionroles', 'cm', '', NULL),
    ('public', 'mcmisccodes', 'mc', '', NULL),
    ('public', 'mcmiscentry', 'mc', '', NULL)

$$ LANGUAGE SQL VOLATILE;

SELECT logging.build_setup();
SELECT logging.deploy();
