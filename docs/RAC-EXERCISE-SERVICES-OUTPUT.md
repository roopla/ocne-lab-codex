# Service, session, backup and scheduling output

[Operations chapter](MANUAL-04-RAC-OPERATIONS.md) | [Scenario workbook](RAC-POD-EXERCISES.md)

This read-only continuation completed with exit0. It found no active user transactions in that observation and no RMAN backup jobs in the control-file view. Neither observation substitutes for the owner confirming a maintenance window or for a verified backup.

Complete command output, 11 October 2026; tabs expanded only for rendering. The collector prints argument lists joined with spaces; copy the properly quoted commands from the workbook rather than treating every printed argument list as a new shell command. No Secret values are included.

```text
Captured UTC: 2026-10-11T19:05:34.531743+00:00

SCENARIO D: services, sessions and backup evidence before any disruptive exercise

$ kubectl exec -n rac racnode1-0 -- su - oracle -c /u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB -verbose
Instance RACCDB1 is running on node racnode1-0 with online services labpdb_app. Instance status: Open.
Instance RACCDB2 is running on node racnode2-0 with online services labpdb_app. Instance status: Open.
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- su - oracle -c /u01/app/oracle/product/19c/dbhome_1/bin/srvctl config service -db RACCDB -service labpdb_app
Service name: labpdb_app
Server pool:
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: false
AQ HA notifications: false
Global: false
Commit Outcome: false
Failover type:
Failover method:
Failover retries:
Failover delay:
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: NONE
Edition:
Pluggable database name: labpdb
Hub service:
Maximum lag time: ANY
SQL Translation Profile:
Retention: 86400 seconds
Replay Initiation Time: 300 seconds
Drain timeout:
Stop option:
Session State Consistency: DYNAMIC
GSM Flags: 0
Service is enabled
Preferred instances: RACCDB1,RACCDB2
Available instances:
CSS critical: no
Service uses Java: false
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- su - oracle -c /u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -i -n rac racnode1-0 -- su - oracle -c export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'

   INST_ID USERNAME     SERVICE_NAME               STATUS     SESSIONS
---------- -------------------- ------------------------------ -------- ----------
     1 SYS          SYS$USERS              ACTIVE        2
     1 SYS          SYS$USERS              INACTIVE      2
     1 SYSRAC       SYS$USERS              INACTIVE      6
     2 SYS          SYS$USERS              ACTIVE        1
     2 SYS          SYS$USERS              INACTIVE      2
     2 SYSRAC       SYS$USERS              INACTIVE      5

6 rows selected.


no rows selected


NAME      LOG_MODE         OPEN_MODE
--------- -------------------- --------------------
RACCDB    ARCHIVELOG           READ WRITE


no rows selected

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

SCENARIO E: current warnings and scheduling capacity

$ kubectl -n rac get events --field-selector=type=Warning --sort-by=.metadata.creationTimestamp
No resources found in rac namespace.
Exit code: 0

$ kubectl get nodes -o custom-columns=NAME:.metadata.name,UNSCHEDULABLE:.spec.unschedulable,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
NAME               UNSCHEDULABLE   CPU   MEMORY
ocne-cp.lab.test   <none>          4     7560516Ki
ocne-w1.lab.test   <none>          6     18877204Ki
ocne-w2.lab.test   <none>          6     18877232Ki
Exit code: 0
Read-only scenario capture completed; no disruption executed.
```

Output presentation: tabs are expanded and trailing padding is removed; raw local logs remain unchanged.
