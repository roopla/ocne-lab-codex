# Database assets - future use

01-create-schemas.sql creates only the application's LAB_TASKS and LAB_NOTES users/tables in the existing LABPDB. It refuses existing users and expects an existing USERS tablespace. 02-verify.sql is read-only acceptance SQL. Neither script was executed during development.

Follow [the deployment walkthrough](../docs/DEPLOYMENT.md). Never rerun RAC provisioning for this application. There is no drop/reset script; preserve app data during failover exercises.
