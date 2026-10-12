-- FUTURE MANUAL STEP. Run as SYSDBA inside LABPDB only. Never automatically executed.
-- Supply two different 32-character hexadecimal passwords from protected files.
SET ECHO OFF VERIFY OFF FEEDBACK ON SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
ALTER SESSION SET CONTAINER = LABPDB;
DECLARE
  n NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV','CON_NAME') <> 'LABPDB' THEN RAISE_APPLICATION_ERROR(-20001,'Wrong PDB'); END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username IN ('LAB_TASKS','LAB_NOTES');
  IF n <> 0 THEN RAISE_APPLICATION_ERROR(-20002,'Application user already exists. Inspect; do not rerun or drop it.'); END IF;
  SELECT COUNT(*) INTO n FROM dba_tablespaces WHERE tablespace_name='USERS' AND status='ONLINE' AND contents='PERMANENT';
  IF n <> 1 THEN RAISE_APPLICATION_ERROR(-20003,'Inspect and choose an existing permanent tablespace before editing this script'); END IF;
  SELECT COUNT(*) INTO n FROM nls_database_parameters WHERE parameter='NLS_CHARACTERSET' AND value='AL32UTF8';
  IF n <> 1 THEN RAISE_APPLICATION_ERROR(-20004,'This lab schema expects AL32UTF8'); END IF;
END;
/
ACCEPT tasks_password CHAR PROMPT 'LAB_TASKS password (32 hex characters; hidden): ' HIDE
ACCEPT notes_password CHAR PROMPT 'LAB_NOTES password (32 hex characters; hidden): ' HIDE
DECLARE
  t VARCHAR2(128) := '&tasks_password';
  n VARCHAR2(128) := '&notes_password';
BEGIN
  IF NOT REGEXP_LIKE(t,'^[0-9a-f]{32}$','c') OR NOT REGEXP_LIKE(n,'^[0-9a-f]{32}$','c') OR t=n THEN
    RAISE_APPLICATION_ERROR(-20005,'Use different 32-character lowercase hexadecimal passwords');
  END IF;
  EXECUTE IMMEDIATE 'CREATE USER LAB_TASKS IDENTIFIED BY "' || t || '" DEFAULT TABLESPACE USERS QUOTA 100M ON USERS';
  EXECUTE IMMEDIATE 'CREATE USER LAB_NOTES IDENTIFIED BY "' || n || '" DEFAULT TABLESPACE USERS QUOTA 100M ON USERS';
END;
/
UNDEFINE tasks_password
UNDEFINE notes_password
GRANT CREATE SESSION TO LAB_TASKS;
GRANT CREATE SESSION TO LAB_NOTES;
CREATE TABLE LAB_TASKS.BOARD_TASKS (
  id VARCHAR2(36 BYTE) CONSTRAINT board_tasks_pk PRIMARY KEY,
  body VARCHAR2(800 BYTE) NOT NULL,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
) TABLESPACE USERS;
CREATE TABLE LAB_NOTES.BOARD_NOTES (
  id VARCHAR2(36 BYTE) CONSTRAINT board_notes_pk PRIMARY KEY,
  body VARCHAR2(800 BYTE) NOT NULL,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
) TABLESPACE USERS;
CREATE INDEX LAB_TASKS.BOARD_TASKS_CREATED ON LAB_TASKS.BOARD_TASKS(created_at DESC,id DESC) TABLESPACE USERS;
CREATE INDEX LAB_NOTES.BOARD_NOTES_CREATED ON LAB_NOTES.BOARD_NOTES(created_at DESC,id DESC) TABLESPACE USERS;
SELECT owner,table_name FROM dba_tables WHERE owner IN ('LAB_TASKS','LAB_NOTES') ORDER BY owner;
PROMPT Schemas created. Expected: LAB_TASKS BOARD_TASKS and LAB_NOTES BOARD_NOTES.
-- DDL auto-commits. If a later statement fails, inspect partial results and finish only missing objects.
EXIT
