-- Read-only; run as SYSDBA after schema creation and again after a failover exercise.
SET LINESIZE 180 PAGESIZE 100
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = LABPDB;
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS pdb FROM dual;
SELECT owner,table_name FROM dba_tables WHERE owner IN ('LAB_TASKS','LAB_NOTES') ORDER BY owner;
SELECT 'tasks' AS kind,COUNT(*) AS rows_total,COUNT(DISTINCT id) AS unique_ids FROM lab_tasks.board_tasks
UNION ALL SELECT 'notes',COUNT(*),COUNT(DISTINCT id) FROM lab_notes.board_notes;
SELECT username,account_status FROM dba_users WHERE username IN ('LAB_TASKS','LAB_NOTES');
SELECT grantee,privilege FROM dba_sys_privs WHERE grantee IN ('LAB_TASKS','LAB_NOTES') ORDER BY grantee,privilege;
SELECT inst_id,name FROM gv$active_services WHERE name LIKE 'labpdb_app%' ORDER BY inst_id;
EXIT
