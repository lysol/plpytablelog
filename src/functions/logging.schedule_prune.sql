/*

    logging.schedule_prune.sql

    While this script is called via the installation script,
    It may be necessary to run the SQL manually if there are more
    databases on the same cluster.

*/


DELETE FROM pgagent.pga_jobstep WHERE jstname = 'logging.prune';
DELETE FROM pgagent.pga_schedule WHERE jscname = 'logging.prune';
DELETE FROM pgagent.pga_job WHERE jobname = 'logging.prune';


INSERT INTO pgagent.pga_job
( jobjclid, jobname, jobdesc, jobenabled )
VALUES
( 1, 'logging.prune', 'Prune old logs from the logging schema.', TRUE );

INSERT INTO pgagent.pga_schedule(jscjobid, jscname, jscenabled, jscminutes, jschours, jscweekdays, jscmonthdays, jscmonths)
VALUES
( currval('pgagent.pga_job_jobid_seq'), 'logging.prune', TRUE, '{f,t,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', '{t,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', '{t,t,t,t,t,t,t}', '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', '{f,f,f,f,f,f,f,f,f,f,f,f}');

INSERT INTO pgagent.pga_jobstep
( jstjobid, jstname, jstenabled, jstkind, jstcode, jstdbname)
VALUES
( currval('pgagent.pga_job_jobid_seq'), 'logging.prune', TRUE, 's', 'SELECT logging.prune();', current_database() );

