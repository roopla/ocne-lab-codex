-- OPTIONAL IRREVERSIBLE DATA DELETION. Uninstall the app and export wanted data first.
SET ECHO OFF VERIFY OFF SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
ALTER SESSION SET CONTAINER=LABPDB;
ACCEPT confirmation CHAR DEFAULT NO PROMPT 'Type DELETE_RAC_BOARD_DATA to permanently delete both app schemas: '
DECLARE
  n NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV','CON_NAME') <> 'LABPDB' OR '&confirmation' <> 'DELETE_RAC_BOARD_DATA' THEN
    RAISE_APPLICATION_ERROR(-20101,'Deletion not confirmed in LABPDB');
  END IF;
  SELECT COUNT(*) INTO n FROM gv$session WHERE username IN ('LAB_TASKS','LAB_NOTES');
  IF n <> 0 THEN RAISE_APPLICATION_ERROR(-20102,'App sessions remain. Stop app clients first; do not kill unrelated sessions.'); END IF;
  SELECT COUNT(*) INTO n FROM dba_constraints WHERE constraint_type='R' AND r_owner IN ('LAB_TASKS','LAB_NOTES') AND owner NOT IN ('LAB_TASKS','LAB_NOTES');
  IF n <> 0 THEN RAISE_APPLICATION_ERROR(-20104,'Other schemas reference app tables. Inspect dependencies before deletion.'); END IF;
  SELECT COUNT(*) INTO n FROM dba_objects WHERE owner IN ('LAB_TASKS','LAB_NOTES') AND NOT (
    (owner='LAB_TASKS' AND ((object_type='TABLE' AND object_name='BOARD_TASKS') OR (object_type='INDEX' AND object_name IN ('BOARD_TASKS_PK','BOARD_TASKS_CREATED')))) OR
    (owner='LAB_NOTES' AND ((object_type='TABLE' AND object_name='BOARD_NOTES') OR (object_type='INDEX' AND object_name IN ('BOARD_NOTES_PK','BOARD_NOTES_CREATED'))))
  );
  IF n <> 0 THEN RAISE_APPLICATION_ERROR(-20103,'Unexpected schema objects; inspect before any deletion'); END IF;
END;
/
DROP USER LAB_TASKS CASCADE;
DROP USER LAB_NOTES CASCADE;
SELECT username FROM dba_users WHERE username IN ('LAB_TASKS','LAB_NOTES');
-- Expected no rows. DDL auto-commits; inspect partial results if either DROP fails.
EXIT
