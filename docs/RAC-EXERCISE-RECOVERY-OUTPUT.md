# RAC recovery preparation and instance exercises: full output

Captured 11 October 2026, 23:38?23:46 UTC. These are actual commands and output, including two unsuccessful wrapper runs and their corrections. No password or Secret payload is included. Tabs are expanded for portable rendering.

## Findings

- Each node now has its own persistent `/etc/oracle` copy, verified byte-for-byte before replacement. This is configuration recovery, separate from the database backup.
- RMAN database plus archivelog, controlfile and SPFILE backups completed with exit 0. `RESTORE DATABASE VALIDATE` read the database backup pieces successfully; it did not restore a database or test point-in-time recovery. Pieces are on worker1 scratch, not an off-host disaster-recovery destination.
- Stopping an instance initially failed with CRS-2974 because `labpdb_app` depended on it. Stop that instance?s service first.
- Starting the instance automatically restored the application service. An unconditional second service start returned PRCR-1120/CRS-5702. Check status before starting an already-running service. Both instances remained healthy after this wrapper error.
- Both instance outages preserved a successful new network SQL connection to LABPDB on the surviving instance. This does not prove transparent session/transaction replay.
- Pods remained Ready during instance/service outages: TCP listener readiness is weaker than SQL acceptance.
- Cordon/uncordon on each worker did not evict existing RAC pods. Both workers were left schedulable.

## Recovery preparation

Local evidence: `logs/ssh-ocne-cp-Prepare-RAC-Exercise-Backups-20261011-193849.txt`.

```text
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
0:0 700 /u01/app/grid/.etcoraclebackup
0:54321 644 /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
0:54321 644 /u01/app/grid/.etcoraclebackup/oracle/olr.loc
efe4eedd0e55084a57754bfe5c910d6cba2d3941edc464cc45bb204afbcc50a6  /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
0a56c40b844766689515081fcea9e911033fc3dfe840563b48f3a58d8d328a86  /u01/app/grid/.etcoraclebackup/oracle/olr.loc
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
0:0 700 /u01/app/grid/.etcoraclebackup
0:54321 644 /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
0:54321 644 /u01/app/grid/.etcoraclebackup/oracle/olr.loc
96efdf847d8894221d27f62ec64d674279f61ee502c852d166dcf04f054ec8f3  /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
dc8605ad62b7ce9bff86715ccc933238fe868835a73a3651e61251b3127ffa7a  /u01/app/grid/.etcoraclebackup/oracle/olr.loc
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
RMAN launcher PID=623146; output=/u01/app/oracle/recovery-backups/manual-exercises-20261011/rman.log
```

## First attempt: dependent service prevented instance stop

Local evidence: `logs/ssh-ocne-cp-Exercise-RAC-Instances-And-Services-20261011-194023.txt`.

```text

UTC 2026-10-11T23:40:23.518504+00:00 $ kubectl exec -n rac racnode1-0 -- cat /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code
0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:23.652861+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:23.953037+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:24.713511+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

SCENARIO S05: stop/start only RACCDB1

UTC 2026-10-11T23:40:24.770464+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop instance -db RACCDB -instance RACCDB1 -stopoption IMMEDIATE'
PRCD-1131 : Failed to stop database RACCDB and its services on nodes racnode1-0
PRCR-1133 : Failed to stop database RACCDB and its running services
PRCR-1132 : Failed to stop resources using a filter
CRS-2974: unable to act on resource 'ora.raccdb.db' on server 'racnode1-0' because that would require stopping or relocating resource 'ora.raccdb.labpdb_app.svc' but the appropriate force flag was not specified
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
command terminated with exit code 1
Exit code: 1

UTC 2026-10-11T23:40:25.768729+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start instance -db RACCDB -instance RACCDB1'
PRCR-1004 : Resource ora.raccdb.db is already running
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
command terminated with exit code 2
Exit code: 2
Traceback (most recent call last):
  File "<stdin>", line 40, in <module>
  File "<stdin>", line 11, in srv
  File "<stdin>", line 10, in k
  File "<stdin>", line 8, in run
RuntimeError: Command failed; review captured output
System.Management.Automation.RemoteException
During handling of the above exception, another exception occurred:
System.Management.Automation.RemoteException
Traceback (most recent call last):
  File "<stdin>", line 45, in <module>
  File "<stdin>", line 11, in srv
  File "<stdin>", line 10, in k
  File "<stdin>", line 8, in run
RuntimeError: Command failed; review captured output
```

## Instance1 recovered; redundant service start reported already running

Local evidence: `logs/ssh-ocne-cp-Exercise-RAC-Instances-And-Services-20261011-194049.txt`.

```text

UTC 2026-10-11T23:40:49.868719+00:00 $ kubectl exec -n rac racnode1-0 -- cat /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code
0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:50.014769+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:50.272857+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:51.060070+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

SCENARIO S05: stop/start only RACCDB1

UTC 2026-10-11T23:40:51.120697+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB1'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:40:52.023152+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop instance -db RACCDB -instance RACCDB1 -stopoption IMMEDIATE'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:41:26.648074+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB -verbose'
Instance RACCDB1 is not running on node racnode1-0
Instance RACCDB2 is running on node racnode2-0 with online services labpdb_app. Instance status: Open.
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:41:27.818994+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:41:27.901374+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:41:28.503455+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start instance -db RACCDB -instance RACCDB1'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:41:52.468197+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start service -db RACCDB -service labpdb_app -instance RACCDB1'
PRCR-1120 : Resources are already running.
CRS-5702: Resource 'ora.raccdb.labpdb_app.svc' is already running on 'racnode1-0'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
command terminated with exit code 2
Exit code: 2
Traceback (most recent call last):
  File "<stdin>", line 51, in <module>
  File "<stdin>", line 11, in srv
  File "<stdin>", line 10, in k
  File "<stdin>", line 8, in run
RuntimeError: Command failed; review captured output
```

## Verified recovery, instance2, service and both cordons

Local evidence: `logs/ssh-ocne-cp-Resume-RAC-Instance-Exercises-20261011-194545.txt`.

```text

UTC 2026-10-11T23:45:46.064956+00:00 $ kubectl exec -n rac racnode1-0 -- cat /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code
0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:45:46.192090+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:45:46.465443+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:45:47.243725+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:45:47.307574+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

SCENARIO S06: stop/start only RACCDB2

UTC 2026-10-11T23:45:47.648776+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB2'
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:45:48.664630+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop instance -db RACCDB -instance RACCDB2 -stopoption IMMEDIATE'
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:13.048699+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB -verbose'
Instance RACCDB1 is running on node racnode1-0 with online services labpdb_app. Instance status: Open.
Instance RACCDB2 is not running on node racnode2-0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:13.876622+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:13.938787+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:14.219815+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start instance -db RACCDB -instance RACCDB2'
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:38.112789+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:39.391138+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:39.808397+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:40.824677+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:40.893660+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0
SCENARIO S06: PASS

SCENARIO S10: application service stop/start on instance1 only

UTC 2026-10-11T23:46:41.438983+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB1'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:42.372989+00:00 $ kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB2
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:44.298527+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:44.370868+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:44.883663+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start service -db RACCDB -service labpdb_app -instance RACCDB1'
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:45.759093+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:46.104759+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:47.233261+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:47.330438+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0
SCENARIO S10: PASS

SCENARIO S12: cordon/uncordon ocne-w1.lab.test

UTC 2026-10-11T23:46:47.752677+00:00 $ kubectl cordon ocne-w1.lab.test
node/ocne-w1.lab.test cordoned
Exit code: 0

UTC 2026-10-11T23:46:47.851392+00:00 $ kubectl get node ocne-w1.lab.test
NAME               STATUS                     ROLES    AGE   VERSION
ocne-w1.lab.test   Ready,SchedulingDisabled   <none>   9d    v1.29.14+2.el9
Exit code: 0

UTC 2026-10-11T23:46:47.937348+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:48.002691+00:00 $ kubectl uncordon ocne-w1.lab.test
node/ocne-w1.lab.test uncordoned
Exit code: 0

UTC 2026-10-11T23:46:48.085713+00:00 $ kubectl get node ocne-w1.lab.test
NAME               STATUS   ROLES    AGE   VERSION
ocne-w1.lab.test   Ready    <none>   9d    v1.29.14+2.el9
Exit code: 0

SCENARIO S12: cordon/uncordon ocne-w2.lab.test

UTC 2026-10-11T23:46:48.161498+00:00 $ kubectl cordon ocne-w2.lab.test
node/ocne-w2.lab.test cordoned
Exit code: 0

UTC 2026-10-11T23:46:48.233899+00:00 $ kubectl get node ocne-w2.lab.test
NAME               STATUS                     ROLES    AGE   VERSION
ocne-w2.lab.test   Ready,SchedulingDisabled   <none>   9d    v1.29.14+2.el9
Exit code: 0

UTC 2026-10-11T23:46:48.301323+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:46:48.364692+00:00 $ kubectl uncordon ocne-w2.lab.test
node/ocne-w2.lab.test uncordoned
Exit code: 0

UTC 2026-10-11T23:46:48.437222+00:00 $ kubectl get node ocne-w2.lab.test
NAME               STATUS   ROLES    AGE   VERSION
ocne-w2.lab.test   Ready    <none>   9d    v1.29.14+2.el9
Exit code: 0

UTC 2026-10-11T23:46:48.507160+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE
     2 LABPDB                                                               READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:48.838867+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:46:49.645214+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0
Sequential instance, service and cordon exercises passed; no pod deleted.
```

## Complete RMAN log

```text

Recovery Manager: Release 19.0.0.0.0 - Production on Sun Oct 11 23:38:50 2026
Version 19.32.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: RACCDB (DBID=3752669671)

RMAN> run {
2>  allocate channel c1 device type disk format '/u01/app/oracle/recovery-backups/manual-exercises-20261011/%U.bkp' maxpiecesize 8G;
3>  backup database plus archivelog;
4>  backup current controlfile;
5>  backup spfile;
6>  restore database validate;
7>  release channel c1;
8> }
9> list backup summary;
10> exit;
using target database control file instead of recovery catalog
allocated channel: c1
channel c1: SID=606 instance=RACCDB1 device type=DISK


Starting backup at 11-OCT-26
current log archived
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=1 sequence=5 RECID=2 STAMP=1246373766
input archived log thread=2 sequence=1 RECID=1 STAMP=1246371460
input archived log thread=2 sequence=2 RECID=3 STAMP=1246373802
input archived log thread=1 sequence=6 RECID=5 STAMP=1246405132
input archived log thread=2 sequence=3 RECID=4 STAMP=1246373803
input archived log thread=2 sequence=4 RECID=6 STAMP=1246405134
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0254l8ge_2_1_1.bkp tag=TAG20261011T233854 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:03
Finished backup at 11-OCT-26

Starting backup at 11-OCT-26
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00001 name=+DATA/RACCDB/DATAFILE/system.264.1246369543
input datafile file number=00003 name=+DATA/RACCDB/DATAFILE/sysaux.265.1246369577
input datafile file number=00004 name=+DATA/RACCDB/DATAFILE/undotbs1.266.1246369593
input datafile file number=00009 name=+DATA/RACCDB/DATAFILE/undotbs2.276.1246370733
input datafile file number=00007 name=+DATA/RACCDB/DATAFILE/users.267.1246369593
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0354l8gh_3_1_1.bkp tag=TAG20261011T233857 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:08
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00010 name=+DATA/RACCDB/5D9244D13030A600E0630901F40A2138/DATAFILE/system.283.1246371567
input datafile file number=00011 name=+DATA/RACCDB/5D9244D13030A600E0630901F40A2138/DATAFILE/sysaux.282.1246371567
input datafile file number=00012 name=+DATA/RACCDB/5D9244D13030A600E0630901F40A2138/DATAFILE/undotbs1.281.1246371567
input datafile file number=00013 name=+DATA/RACCDB/5D9244D13030A600E0630901F40A2138/DATAFILE/undo_2.285.1246371579
input datafile file number=00014 name=+DATA/RACCDB/5D9244D13030A600E0630901F40A2138/DATAFILE/users.286.1246371581
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0454l8gp_4_1_1.bkp tag=TAG20261011T233857 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
input datafile file number=00005 name=+DATA/RACCDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/system.272.1246370529
input datafile file number=00006 name=+DATA/RACCDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/sysaux.273.1246370529
input datafile file number=00008 name=+DATA/RACCDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/undotbs1.274.1246370529
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0554l8h0_5_1_1.bkp tag=TAG20261011T233857 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:07
Finished backup at 11-OCT-26

Starting backup at 11-OCT-26
current log archived
channel c1: starting archived log backup set
channel c1: specifying archived log(s) in backup set
input archived log thread=1 sequence=7 RECID=8 STAMP=1246405159
input archived log thread=2 sequence=5 RECID=7 STAMP=1246405139
input archived log thread=2 sequence=6 RECID=9 STAMP=1246405160
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0654l8h9_6_1_1.bkp tag=TAG20261011T233920 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:01
Finished backup at 11-OCT-26

Starting backup at 11-OCT-26
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
including current control file in backup set
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0754l8ha_7_1_1.bkp tag=TAG20261011T233922 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:01
Finished backup at 11-OCT-26

Starting backup at 11-OCT-26
channel c1: starting full datafile backup set
channel c1: specifying datafile(s) in backup set
including current SPFILE in backup set
channel c1: starting piece 1 at 11-OCT-26
channel c1: finished piece 1 at 11-OCT-26
piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0854l8hc_8_1_1.bkp tag=TAG20261011T233924 comment=NONE
channel c1: backup set complete, elapsed time: 00:00:01
Finished backup at 11-OCT-26

Starting Control File and SPFILE Autobackup at 11-OCT-26
piece handle=+DATA/RACCDB/AUTOBACKUP/2026_10_11/s_1246405165.297.1246405165 comment=NONE
Finished Control File and SPFILE Autobackup at 11-OCT-26

Starting restore at 11-OCT-26

channel c1: starting validation of datafile backup set
channel c1: reading from backup piece /u01/app/oracle/recovery-backups/manual-exercises-20261011/0354l8gh_3_1_1.bkp
channel c1: piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0354l8gh_3_1_1.bkp tag=TAG20261011T233857
channel c1: restored backup piece 1
channel c1: validation complete, elapsed time: 00:00:03
channel c1: starting validation of datafile backup set
channel c1: reading from backup piece /u01/app/oracle/recovery-backups/manual-exercises-20261011/0454l8gp_4_1_1.bkp
channel c1: piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0454l8gp_4_1_1.bkp tag=TAG20261011T233857
channel c1: restored backup piece 1
channel c1: validation complete, elapsed time: 00:00:01
channel c1: starting validation of datafile backup set
channel c1: reading from backup piece /u01/app/oracle/recovery-backups/manual-exercises-20261011/0554l8h0_5_1_1.bkp
channel c1: piece handle=/u01/app/oracle/recovery-backups/manual-exercises-20261011/0554l8h0_5_1_1.bkp tag=TAG20261011T233857
channel c1: restored backup piece 1
channel c1: validation complete, elapsed time: 00:00:01
Finished restore at 11-OCT-26

released channel: c1


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
1       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T142913
2       B  A  A DISK        11-OCT-26       1       1       NO         TAG20261011T233854
3       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233857
4       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233857
5       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233857
6       B  A  A DISK        11-OCT-26       1       1       NO         TAG20261011T233920
7       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233922
8       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233924
9       B  F  A DISK        11-OCT-26       1       1       NO         TAG20261011T233925

Recovery Manager complete.
```

See [the operations workbook](RAC-POD-EXERCISES.md) and [manual chapter 4](MANUAL-04-RAC-OPERATIONS.md) for the corrected commands.

Output presentation: tabs are expanded and trailing padding is removed; raw local logs remain unchanged.
