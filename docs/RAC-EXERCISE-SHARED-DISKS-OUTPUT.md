# Shared ASM candidate disk exercise: captured output

14 October 2026. See [the step-by-step guide](RAC-ADD-SHARED-CANDIDATE-DISKS.md) for execution location, commands, expected results and interpretation. These are selected actual execution logs, including failures and corrections. Line endings and whitespace-only lines were normalized and tabs expanded to spaces; no passwords, keys or credential contents are included. The old ORCLPDB string in the CR summary is stale operator display metadata; SQL and app checks verify LABPDB.

## Worker 1 blank media and recovery labels

Local evidence file: `logs/ssh-ocne-w1-Inspect-RAC-Spare-Disks-20261014-081023.txt`.

```text
Wed Oct 14 12:10:23 PM UTC 2026
ocne-w1.lab.test
NAME           SIZE TYPE FSTYPE    MOUNTPOINTS                         PARTLABEL      PARTUUID                             SERIAL
loop0   53684994048 loop oracleasm
loop1   53684994048 loop oracleasm
sda    107374182400 disk                                                                                                   VB2a09e7bc-00453cd8
├─sda1   1073741824 part xfs       /boot                                              32bdb96b-01
└─sda2 106299375104 part xfs       /                                                  32bdb96b-02
sdb    107374182400 disk xfs       /var/lib/containers/storage/overlay                                                     VB7ccb5a40-510bce8c
                                   /var/lib/containers
sdc    137438953472 disk xfs       /scratch                                                                                VB323d540b-8e123255
sdd     53687091200 disk                                                                                                   VBdb34f551-507d0f5a
└─sdd1  53684994048 part oracleasm                                     ocne-rac-asm01 c25151a5-4557-444f-916f-cc359f3fd43b
sde     53687091200 disk                                                                                                   VBc280454f-7e0f28bc
└─sde1  53684994048 part oracleasm                                     ocne-rac-asm02 14cb5bdb-e6ff-4706-b82f-b0f748df5157
sdf     53687091200 disk                                                                                                   VBc4bffe32-d7efc6fc
sdg     53687091200 disk                                                                                                   VB35658d62-769d5796
Read-only signatures: /dev/sda
DEVICE OFFSET TYPE UUID LABEL
sda    0x1fe  dos
Read-only signatures: /dev/sdb
DEVICE OFFSET TYPE UUID                                 LABEL
sdb    0x0    xfs  1ca6c397-b848-4e95-a24a-a96ea11a55cc
Read-only signatures: /dev/sdc
DEVICE OFFSET TYPE UUID                                 LABEL
sdc    0x0    xfs  48e2e0e8-d37d-4262-a2d3-67b40eacf76b rac-scratch1
Read-only signatures: /dev/sdd
DEVICE OFFSET      TYPE UUID LABEL
sdd    0x200       gpt
sdd    0xc7ffffe00 gpt
sdd    0x1fe       PMBR
Read-only signatures: /dev/sde
DEVICE OFFSET      TYPE UUID LABEL
sde    0x200       gpt
sde    0xc7ffffe00 gpt
sde    0x1fe       PMBR
Read-only signatures: /dev/sdf
Read-only signatures: /dev/sdg
drwx------. 3 root root  system_u:object_r:container_file_t:s0  20 Oct 11 19:38 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0 151 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0  96 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc
/scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc        system_u:object_r:container_file_t:s0
Enforcing
TARGET   SOURCE   FSTYPE OPTIONS
/scratch /dev/sdc xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
```

## Worker 2 blank media and recovery labels

Local evidence file: `logs/ssh-ocne-w2-Inspect-RAC-Spare-Disks-20261014-081011.txt`.

```text
Wed Oct 14 12:10:11 PM UTC 2026
ocne-w2.lab.test
NAME           SIZE TYPE FSTYPE    MOUNTPOINTS                         PARTLABEL      PARTUUID                             SERIAL
loop0   53684994048 loop oracleasm
loop1   53684994048 loop oracleasm
sda    107374182400 disk                                                                                                   VBebbcf406-677a5500
├─sda1   1073741824 part xfs       /boot                                              32bdb96b-01
└─sda2 106299375104 part xfs       /                                                  32bdb96b-02
sdb    107374182400 disk xfs       /var/lib/containers/storage/overlay                                                     VB447ca102-bbeaa08c
                                   /var/lib/containers
sdc    137438953472 disk xfs       /scratch                                                                                VBa7088f24-017bb508
sdd     53687091200 disk                                                                                                   VBdb34f551-507d0f5a
└─sdd1  53684994048 part oracleasm                                     ocne-rac-asm01 c25151a5-4557-444f-916f-cc359f3fd43b
sde     53687091200 disk                                                                                                   VBc280454f-7e0f28bc
└─sde1  53684994048 part oracleasm                                     ocne-rac-asm02 14cb5bdb-e6ff-4706-b82f-b0f748df5157
sdf     53687091200 disk                                                                                                   VBc4bffe32-d7efc6fc
sdg     53687091200 disk                                                                                                   VB35658d62-769d5796
Read-only signatures: /dev/sda
DEVICE OFFSET TYPE UUID LABEL
sda    0x1fe  dos
Read-only signatures: /dev/sdb
DEVICE OFFSET TYPE UUID                                 LABEL
sdb    0x0    xfs  50e55c0d-a63c-41c4-b66c-7a46cae288ab
Read-only signatures: /dev/sdc
DEVICE OFFSET TYPE UUID                                 LABEL
sdc    0x0    xfs  8d744a6a-39bf-4cb4-9ab3-739dbff7c319 rac-scratch2
Read-only signatures: /dev/sdd
DEVICE OFFSET      TYPE UUID LABEL
sdd    0x200       gpt
sdd    0xc7ffffe00 gpt
sdd    0x1fe       PMBR
Read-only signatures: /dev/sde
DEVICE OFFSET      TYPE UUID LABEL
sde    0x200       gpt
sde    0xc7ffffe00 gpt
sde    0x1fe       PMBR
Read-only signatures: /dev/sdf
Read-only signatures: /dev/sdg
drwx------. 3 root root  system_u:object_r:container_file_t:s0  20 Oct 11 19:38 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0 151 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0  96 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc
/scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc        system_u:object_r:container_file_t:s0
Enforcing
TARGET   SOURCE   FSTYPE OPTIONS
/scratch /dev/sdc xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
```

## Worker 1 guarded partition creation

Local evidence file: `logs/ssh-ocne-w1-Prepare-RAC-Spare-Partitions-20261014-082055.txt`.

```text
Verified blank 50 GiB ASM disk: /dev/sdf VBc4bffe32-d7efc6fc
Verified blank 50 GiB ASM disk: /dev/sdg VB35658d62-769d5796
NAME          SIZE TYPE FSTYPE PARTLABEL      PARTUUID                             SERIAL
sdf    53687091200 disk                                                            VBc4bffe32-d7efc6fc
└─sdf1 53684994048 part        ocne-rac-asm03 4ada60ba-ae3c-45b0-9a86-aa656fbb57e6
NAME          SIZE TYPE FSTYPE PARTLABEL      PARTUUID                             SERIAL
sdg    53687091200 disk                                                            VB35658d62-769d5796
└─sdg1 53684994048 part        ocne-rac-asm04 1bd08689-797c-4d7b-834c-cee370025d39
```

## Worker 2 partition UUID verification

Local evidence file: `logs/ssh-ocne-w2-Refresh-RAC-Spare-Partitions-20261014-082125.txt`.

```text
NAME          SIZE TYPE FSTYPE PARTLABEL      PARTUUID                             SERIAL
sdf    53687091200 disk                                                            VBc4bffe32-d7efc6fc
└─sdf1 53684994048 part        ocne-rac-asm03 4ada60ba-ae3c-45b0-9a86-aa656fbb57e6
NAME          SIZE TYPE FSTYPE PARTLABEL      PARTUUID                             SERIAL
sdg    53687091200 disk                                                            VB35658d62-769d5796
└─sdg1 53684994048 part        ocne-rac-asm04 1bd08689-797c-4d7b-834c-cee370025d39
```

## Server dry-run and spec comparison

Local evidence file: `logs/ssh-ocne-cp-Preflight-RAC-Spare-Update-20261014-082204.txt`.

```text
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Other spec fields changed: []
[
  {
    "disks": [
      "/dev/disk/by-partlabel/ocne-rac-asm01",
      "/dev/disk/by-partlabel/ocne-rac-asm02"
    ],
    "name": "DATA",
    "redundancy": "EXTERNAL",
    "type": "CRSDG"
  },
  {
    "autoUpdate": "false",
    "disks": [
      "/dev/disk/by-partlabel/ocne-rac-asm03",
      "/dev/disk/by-partlabel/ocne-rac-asm04"
    ],
    "name": "SPAREDISKS",
    "type": "OTHERS"
  }
]
PASS: server dry-run accepted; only spare disk group entry changes
Snapshots: /home/labadmin/asm-spares-20261014
```

## Node 1 replacement and trailing delimiter error

Local evidence file: `logs/asm-spares-replace-node1-20261014.txt`.

```text
ssh : /home/labadmin/asm-spares-20261014/Replace-RAC-Pod-For-Spares.sh: line 64: warning: here-document at line 6
delimited by end-of-file (wanted `PY')
At line:70 char:1
+ ssh -F config/windows-ssh.conf ocne-cp 'bash -n ~/asm-spares-20261014 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (/home/labadmin/...e (wanted `PY'):String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError

/home/labadmin/asm-spares-20261014/Replace-RAC-Pod-For-Spares.sh: line 64: warning: here-document at line 6 delimited
by end-of-file (wanted `PY')

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 LABPDB                                                                                                                           READ WRITE
         2 LABPDB                                                                                                                           READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
START 2026-10-14T12:32:35.714975+00:00 racnode1-0 old UID 590e8b8f-3a93-43d1-a8ea-3549e6b83201
pod "racnode1-0" deleted
2026-10-14T12:32:35.863059+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:32:50.955998+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:33:06.025770+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:33:21.101346+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:33:36.186532+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:33:51.272805+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:34:06.362140+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:34:21.452737+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:34:36.541395+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready True
2026-10-14T12:34:51.640937+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:35:06.736539+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:35:21.811792+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:35:36.899781+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:35:51.972325+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:36:07.053983+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:36:22.134248+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:36:37.223789+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:36:52.303604+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:37:07.380981+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:37:22.495793+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:37:37.557540+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready False
2026-10-14T12:37:52.643031+00:00 racnode1-0 98728859-0a26-4339-af70-5d5d2ebcd5f7 Running Ready True
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 LABPDB                                                                                                                           READ WRITE
         2 LABPDB                                                                                                                           READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
NAME         READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          3m16s   10.244.1.24   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          2d12h   10.244.2.10   ocne-w2.lab.test   <none>           <none>
PASS racnode1-0 new UID 98728859-0a26-4339-af70-5d5d2ebcd5f7 four mapped devices; both DB instances and PDBs open
Traceback (most recent call last):
  File "<stdin>", line 58, in <module>
NameError: name 'PY' is not defined
```

## First candidate query and unsupported ASM PL/SQL assertion

Local evidence file: `logs/asm-spares-node1-candidates-20261014.txt`.

```text
/dev/disk/by-partlabel/ocne-rac-asm01 asm-pv-16e0716b-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm02 asm-pv-ee86c2c9-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm03 asm-pv-9e992939-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm04 asm-pv-4775bc2f-rac19c Bound Block
racnode1-0 UID 98728859-0a26-4339-af70-5d5d2ebcd5f7 all four devices mapped
brw-rw----. 1 grid asmadmin 8, 49 Oct 14 23:31 /dev/disk/by-partlabel/ocne-rac-asm01
brw-rw----. 1 grid asmadmin 8, 65 Oct 14 23:31 /dev/disk/by-partlabel/ocne-rac-asm02
brw-rw-rw-. 1 root disk     8, 81 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm03
brw-rw-rw-. 1 root disk     8, 97 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm04
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
asm_diskstring                       string      /dev/disk/by-partlabel/ocne-ra
                                                 c-asm*

PATH                                                 HEADER_STATU MOUNT_S MODE_ST STATE    GROUP_NUMBER   TOTAL_MB
---------------------------------------------------- ------------ ------- ------- -------- ------------ ----------
/dev/disk/by-partlabel/ocne-rac-asm01                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm02                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm03                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0
/dev/disk/by-partlabel/ocne-rac-asm04                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0


NAME               TYPE   STATE         TOTAL_MB    FREE_MB
------------------ ------ ----------- ---------- ----------
DATA               EXTERN MOUNTED         102392      87964

 if n<>2 then raise_application_error(-20001,'Expected two unused candidate disks'); end if;
              *
ERROR at line 3:
ORA-06550: line 3, column 15:
PLS-00201: identifier 'RAISE_APPLICATION_ERROR' must be declared
ORA-06550: line 3, column 15:
PL/SQL: Statement ignored
ORA-06550: line 5, column 15:
PLS-00201: identifier 'RAISE_APPLICATION_ERROR' must be declared
ORA-06550: line 5, column 15:
PL/SQL: Statement ignored
ORA-06550: line 7, column 15:
PLS-00201: identifier 'RAISE_APPLICATION_ERROR' must be declared
ORA-06550: line 7, column 15:
PL/SQL: Statement ignored
ORA-06550: line 9, column 15:
PLS-00201: identifier 'RAISE_APPLICATION_ERROR' must be declared
ORA-06550: line 9, column 15:
PL/SQL: Statement ignored


Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
command terminated with exit code 1
ssh : Traceback (most recent call last):
At line:4 char:1
+ ssh -F config/windows-ssh.conf ocne-cp 'bash -n ~/asm-spares-20261014 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (Traceback (most recent call last)::String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError

  File "<stdin>", line 41, in <module>
  File "<stdin>", line 6, in k
RuntimeError: kubectl failed
```

## Corrected candidate query before touching node 2

Local evidence file: `logs/asm-spares-node1-candidates-corrected-20261014.txt`.

```text
/dev/disk/by-partlabel/ocne-rac-asm01 asm-pv-16e0716b-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm02 asm-pv-ee86c2c9-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm03 asm-pv-9e992939-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm04 asm-pv-4775bc2f-rac19c Bound Block
racnode1-0 UID 98728859-0a26-4339-af70-5d5d2ebcd5f7 all four devices mapped
brw-rw----. 1 grid asmadmin 8, 49 Oct 14 23:32 /dev/disk/by-partlabel/ocne-rac-asm01
brw-rw----. 1 grid asmadmin 8, 65 Oct 14 23:32 /dev/disk/by-partlabel/ocne-rac-asm02
brw-rw-rw-. 1 root disk     8, 81 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm03
brw-rw-rw-. 1 root disk     8, 97 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm04
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
asm_diskstring                       string      /dev/disk/by-partlabel/ocne-ra
                                                 c-asm*

PATH                                                 HEADER_STATU MOUNT_S MODE_ST STATE    GROUP_NUMBER   TOTAL_MB
---------------------------------------------------- ------------ ------- ------- -------- ------------ ----------
/dev/disk/by-partlabel/ocne-rac-asm01                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm02                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm03                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0
/dev/disk/by-partlabel/ocne-rac-asm04                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0


NAME               TYPE   STATE         TOTAL_MB    FREE_MB
------------------ ------ ----------- ---------- ----------
DATA               EXTERN MOUNTED         102392      87964


CANDIDATE_CHECK
---------------
              1


MEMBER_CHECK
------------
           1


DATA_CHECK
----------
         1


PLACEHOLDER_CHECK
-----------------
                1

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
PASS: selected ASM instances discover two CANDIDATE disks; DATA unchanged
```

## Node 2 replacement with corrected wrapper

Local evidence file: `logs/asm-spares-replace-node2-20261014.txt`.

```text

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 LABPDB                                                                                                                           READ WRITE
         2 LABPDB                                                                                                                           READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
START 2026-10-14T23:32:23.226190+00:00 racnode2-0 old UID e5fb5f48-cfcc-4476-97d9-07338262095d
pod "racnode2-0" deleted
2026-10-14T23:32:23.385906+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:32:38.452653+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:32:53.543039+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:33:08.626127+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:33:23.707808+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:33:38.802845+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:33:53.884525+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:34:08.965755+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready True
2026-10-14T23:34:24.051160+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Failed Ready False
2026-10-14T23:34:39.139965+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:34:54.227916+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:35:09.314844+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:35:24.405441+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:35:39.496753+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:35:54.584878+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:36:09.668489+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:36:24.762348+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:36:39.852880+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:36:54.935913+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:37:10.041273+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready False
2026-10-14T23:37:25.161652+00:00 racnode2-0 05ce7fd1-3172-4bdd-82f9-faeae76484c9 Running Ready True
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 LABPDB                                                                                                                           READ WRITE
         2 LABPDB                                                                                                                           READ WRITE


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
NAME         READY   STATUS    RESTARTS   AGE    IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          11h    10.244.1.24   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          3m1s   10.244.2.28   ocne-w2.lab.test   <none>           <none>
PASS racnode2-0 new UID 05ce7fd1-3172-4bdd-82f9-faeae76484c9 four mapped devices; both DB instances and PDBs open
```

## Device ownership correction

Local evidence file: `logs/ssh-ocne-cp-Set-RAC-Spare-Permissions-20261014-193453.txt`.

```text
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
uid=54332(grid) gid=54321(oinstall) groups=54321(oinstall),54322(dba),54330(racdba),54334(asmadmin),54335(asmdba),54336(asmoper)
asmadmin:x:54334:grid,oracle
grid:asmadmin 660 /dev/disk/by-partlabel/ocne-rac-asm03
grid:asmadmin 660 /dev/disk/by-partlabel/ocne-rac-asm04
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
uid=54332(grid) gid=54321(oinstall) groups=54321(oinstall),54322(dba),54330(racdba),54334(asmadmin),54335(asmdba),54336(asmoper)
asmadmin:x:54334:grid,oracle
grid:asmadmin 660 /dev/disk/by-partlabel/ocne-rac-asm03
grid:asmadmin 660 /dev/disk/by-partlabel/ocne-rac-asm04
```

## Final both-instance candidate/permissions verification

Local evidence file: `logs/ssh-ocne-cp-Verify-RAC-Spare-Candidates-20261014-193734.txt`.

```text
/dev/disk/by-partlabel/ocne-rac-asm01 asm-pv-16e0716b-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm02 asm-pv-ee86c2c9-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm03 asm-pv-9e992939-rac19c Bound Block
/dev/disk/by-partlabel/ocne-rac-asm04 asm-pv-4775bc2f-rac19c Bound Block
racnode1-0 UID 98728859-0a26-4339-af70-5d5d2ebcd5f7 all four devices mapped
brw-rw----. 1 grid asmadmin 8, 49 Oct 14 23:37 /dev/disk/by-partlabel/ocne-rac-asm01
brw-rw----. 1 grid asmadmin 8, 65 Oct 14 23:37 /dev/disk/by-partlabel/ocne-rac-asm02
brw-rw----. 1 grid asmadmin 8, 81 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm03
brw-rw----. 1 grid asmadmin 8, 97 Oct 14 12:34 /dev/disk/by-partlabel/ocne-rac-asm04
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
grid:asmadmin 660
grid:asmadmin 660
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
asm_diskstring                       string      /dev/disk/by-partlabel/ocne-ra
                                                 c-asm*

PATH                                                 HEADER_STATU MOUNT_S MODE_ST STATE    GROUP_NUMBER   TOTAL_MB
---------------------------------------------------- ------------ ------- ------- -------- ------------ ----------
/dev/disk/by-partlabel/ocne-rac-asm01                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm02                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm03                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0
/dev/disk/by-partlabel/ocne-rac-asm04                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0


NAME               TYPE   STATE         TOTAL_MB    FREE_MB
------------------ ------ ----------- ---------- ----------
DATA               EXTERN MOUNTED         102392      87900


CANDIDATE_CHECK
---------------
              1


MEMBER_CHECK
------------
           1


DATA_CHECK
----------
         1


PLACEHOLDER_CHECK
-----------------
                1

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
racnode2-0 UID 05ce7fd1-3172-4bdd-82f9-faeae76484c9 all four devices mapped
brw-rw----. 1 grid asmadmin 8, 49 Oct 14 23:37 /dev/disk/by-partlabel/ocne-rac-asm01
brw-rw----. 1 grid asmadmin 8, 65 Oct 14 23:37 /dev/disk/by-partlabel/ocne-rac-asm02
brw-rw----. 1 grid asmadmin 8, 81 Oct 14 23:34 /dev/disk/by-partlabel/ocne-rac-asm03
brw-rw----. 1 grid asmadmin 8, 97 Oct 14 23:34 /dev/disk/by-partlabel/ocne-rac-asm04
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
grid:asmadmin 660
grid:asmadmin 660
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
asm_diskstring                       string      /dev/disk/by-partlabel/ocne-ra
                                                 c-asm*

PATH                                                 HEADER_STATU MOUNT_S MODE_ST STATE    GROUP_NUMBER   TOTAL_MB
---------------------------------------------------- ------------ ------- ------- -------- ------------ ----------
/dev/disk/by-partlabel/ocne-rac-asm01                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm02                MEMBER       CACHED  ONLINE  NORMAL              1      51196
/dev/disk/by-partlabel/ocne-rac-asm03                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0
/dev/disk/by-partlabel/ocne-rac-asm04                CANDIDATE    CLOSED  ONLINE  NORMAL              0          0


NAME               TYPE   STATE         TOTAL_MB    FREE_MB
------------------ ------ ----------- ---------- ----------
DATA               EXTERN MOUNTED         102392      87900


CANDIDATE_CHECK
---------------
              1


MEMBER_CHECK
------------
           1


DATA_CHECK
----------
         1


PLACEHOLDER_CHECK
-----------------
                1

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
PASS: selected ASM instances discover two CANDIDATE disks; DATA unchanged
```

## Final complete database acceptance

Local evidence file: `logs/ssh-ocne-cp-Verify-RAC-Database-20261014-193736.txt`.

```text
RacDatabase AVAILABLE
pod/racnode1-0 condition met
pod/racnode2-0 condition met
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
racnode1-0      1
racnode2-0      2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    87900                0           87900              0             Y  DATA/
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
39526364;OCW RELEASE UPDATE 19.32.0.0.0 (39526364)
39503034;ACFS RELEASE UPDATE 19.32.0.0.0 (39503034)
39472050;Database Release Update : 19.32.0.0.260721 (39472050)
39107855;TOMCAT RELEASE UPDATE 19.0.0.0.0 (39107855)
39107825;DBWLM RELEASE UPDATE 19.0.0.0.0 (39107825)
39222882;OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)

OPatch succeeded.
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
39526364;OCW RELEASE UPDATE 19.32.0.0.0 (39526364)
39472050;Database Release Update : 19.32.0.0.260721 (39472050)
39222882;OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)

OPatch succeeded.
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


NAME      OPEN_MODE            DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 PDB$SEED                                                                                                                         READ ONLY
         1 LABPDB                                                                                                                           READ WRITE
         2 PDB$SEED                                                                                                                         READ ONLY
         2 LABPDB                                                                                                                           READ WRITE


   INST_ID NAME
---------- --------------------------------------------------------------------------------
VALUE
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
         1 cluster_database
TRUE

         2 cluster_database
TRUE

         1 pga_aggregate_target
2147483648

         2 pga_aggregate_target
2147483648

         1 sga_target
3221225472

         2 sga_target
3221225472

         1 use_large_pages
FALSE

         2 use_large_pages
FALSE


8 rows selected.


    CON_ID   PATCH_ID ACTION          STATUS                    DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
         1   39222882 APPLY           SUCCESS                   OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
         1   39472050 APPLY           SUCCESS                   Database Release Update : 19.32.0.0.260721 (39472050)
         3   39222882 APPLY           SUCCESS                   OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
         3   39472050 APPLY           SUCCESS                   Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
racnode1-0      1
racnode2-0      2
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    87900                0           87900              0             Y  DATA/
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
39526364;OCW RELEASE UPDATE 19.32.0.0.0 (39526364)
39503034;ACFS RELEASE UPDATE 19.32.0.0.0 (39503034)
39472050;Database Release Update : 19.32.0.0.260721 (39472050)
39107855;TOMCAT RELEASE UPDATE 19.0.0.0.0 (39107855)
39107825;DBWLM RELEASE UPDATE 19.0.0.0.0 (39107825)
39222882;OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)

OPatch succeeded.
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
39526364;OCW RELEASE UPDATE 19.32.0.0.0 (39526364)
39472050;Database Release Update : 19.32.0.0.260721 (39472050)
39222882;OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)

OPatch succeeded.
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)

   INST_ID INSTANCE_NAME    STATUS       DATABASE_STATUS
---------- ---------------- ------------ -----------------
         1 RACCDB1          OPEN         ACTIVE
         2 RACCDB2          OPEN         ACTIVE


NAME      OPEN_MODE            DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                                                                             OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
         1 PDB$SEED                                                                                                                         READ ONLY
         1 LABPDB                                                                                                                           READ WRITE
         2 PDB$SEED                                                                                                                         READ ONLY
         2 LABPDB                                                                                                                           READ WRITE


   INST_ID NAME
---------- --------------------------------------------------------------------------------
VALUE
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
         1 cluster_database
TRUE

         2 cluster_database
TRUE

         1 pga_aggregate_target
2147483648

         2 pga_aggregate_target
2147483648

         1 sga_target
3221225472

         2 sga_target
3221225472

         1 use_large_pages
FALSE

         2 use_large_pages
FALSE


8 rows selected.


    CON_ID   PATCH_ID ACTION          STATUS                    DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
         1   39222882 APPLY           SUCCESS                   OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
         1   39472050 APPLY           SUCCESS                   Database Release Update : 19.32.0.0.260721 (39472050)
         3   39222882 APPLY           SUCCESS                   OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
         3   39472050 APPLY           SUCCESS                   Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DBLSNR.lsnr
               ONLINE  ONLINE       racnode1-0               STABLE
               ONLINE  ONLINE       racnode2-0               STABLE
ora.LISTENER.lsnr
               ONLINE  ONLINE       racnode1-0               STABLE
               ONLINE  ONLINE       racnode2-0               STABLE
ora.chad
               ONLINE  ONLINE       racnode1-0               STABLE
               ONLINE  ONLINE       racnode2-0               STABLE
ora.net1.network
               ONLINE  ONLINE       racnode1-0               STABLE
               ONLINE  ONLINE       racnode2-0               STABLE
ora.ons
               ONLINE  ONLINE       racnode1-0               STABLE
               ONLINE  ONLINE       racnode2-0               STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.ASMNET2LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.DATA.dg(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       racnode1-0               STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       racnode2-0               STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               Started,STABLE
      2        ONLINE  ONLINE       racnode2-0               Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.asmnet2.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.cvu
      1        ONLINE  ONLINE       racnode1-0               STABLE
ora.raccdb.db
      1        ONLINE  ONLINE       racnode1-0               Open,HOME=/u01/app/o
                                                             racle/product/19c/db
                                                             home_1,STABLE
      2        ONLINE  ONLINE       racnode2-0               Open,HOME=/u01/app/o
                                                             racle/product/19c/db
                                                             home_1,STABLE
ora.raccdb.labpdb_app.svc
      1        ONLINE  ONLINE       racnode1-0               STABLE
      2        ONLINE  ONLINE       racnode2-0               STABLE
ora.racnode1-0.vip
      1        ONLINE  ONLINE       racnode1-0               STABLE
ora.racnode2-0.vip
      1        ONLINE  ONLINE       racnode2-0               STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       racnode1-0               STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       racnode2-0               STABLE
--------------------------------------------------------------------------------
Instance RACCDB1 is running on node racnode1-0 with online services labpdb_app. Instance status: Open.
Instance RACCDB2 is running on node racnode2-0 with online services labpdb_app. Instance status: Open.
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
```

## Final application/cluster status and image startup observations

Local evidence file: `logs/ssh-ocne-cp-Capture-RAC-Spare-Final-20261014-193807.txt`.

```text
Wed Oct 14 11:38:07 PM UTC 2026
NAME               STATUS   ROLES           AGE   VERSION
ocne-cp.lab.test   Ready    control-plane   12d   v1.29.14+2.el9
ocne-w1.lab.test   Ready    <none>          12d   v1.29.14+2.el9
ocne-w2.lab.test   Ready    <none>          12d   v1.29.14+2.el9
NAME     DBNAME   DBSTATE   ROLE      VERSION       PDB CONNECT STR             STATE
rac19c   RACCDB   OPEN      PRIMARY   19.32.0.0.0   racnode-scan:1521/ORCLPDB   AVAILABLE
NAME             READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
pod/racnode1-0   1/1     Running   0          11h     10.244.1.24   ocne-w1.lab.test   <none>           <none>
pod/racnode2-0   1/1     Running   0          3m43s   10.244.2.28   ocne-w2.lab.test   <none>           <none>

NAME                                            STATUS   VOLUME                   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE     VOLUMEMODE
persistentvolumeclaim/asm-pvc-16e0716b-rac19c   Bound    asm-pv-16e0716b-rac19c   49Gi       RWX                           <unset>                 3d21h   Block
persistentvolumeclaim/asm-pvc-4775bc2f-rac19c   Bound    asm-pv-4775bc2f-rac19c   49Gi       RWX                           <unset>                 11h     Block
persistentvolumeclaim/asm-pvc-9e992939-rac19c   Bound    asm-pv-9e992939-rac19c   49Gi       RWX                           <unset>                 11h     Block
persistentvolumeclaim/asm-pvc-ee86c2c9-rac19c   Bound    asm-pv-ee86c2c9-rac19c   49Gi       RWX                           <unset>                 3d21h   Block
NAME                              READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
board-frontend-6d45679b8c-wps22   1/1     Running   0          36h   10.244.2.12   ocne-w2.lab.test   <none>           <none>
board-frontend-6d45679b8c-z8rfb   1/1     Running   0          36h   10.244.1.17   ocne-w1.lab.test   <none>           <none>
board-gateway-654f76bb55-krsr2    1/1     Running   0          36h   10.244.2.16   ocne-w2.lab.test   <none>           <none>
board-gateway-654f76bb55-qdvmb    1/1     Running   0          36h   10.244.1.14   ocne-w1.lab.test   <none>           <none>
board-notes-558f6cb9fd-ccvk6      1/1     Running   0          36h   10.244.2.18   ocne-w2.lab.test   <none>           <none>
board-notes-558f6cb9fd-wqlq9      1/1     Running   0          36h   10.244.1.13   ocne-w1.lab.test   <none>           <none>
board-tasks-6cb95b78dd-l42vz      1/1     Running   0          36h   10.244.1.15   ocne-w1.lab.test   <none>           <none>
board-tasks-6cb95b78dd-xtd2h      1/1     Running   0          36h   10.244.2.17   ocne-w2.lab.test   <none>           <none>
http://192.168.77.12:30080/api/status {
  "gateway": "board-gateway-654f76bb55-krsr2",
  "services": {
    "tasks": {
      "healthy": true,
      "ok": true,
      "mode": "oracle",
      "pod": "board-tasks-6cb95b78dd-l42vz",
      "instance": "RACCDB1",
      "pdb": "LABPDB",
      "databaseService": "labpdb_app",
      "service": "python-tasks"
    },
    "notes": {
      "healthy": true,
      "databaseService": "labpdb_app",
      "pdb": "LABPDB",
      "service": "java-notes",
      "mode": "oracle",
      "pod": "board-notes-558f6cb9fd-wqlq9",
      "instance": "RACCDB2"
    }
  },
  "checkedAt": "2026-10-14T23:38:07.746Z"
}
http://192.168.77.13:30080/api/status {
  "gateway": "board-gateway-654f76bb55-qdvmb",
  "services": {
    "tasks": {
      "healthy": true,
      "ok": true,
      "mode": "oracle",
      "pod": "board-tasks-6cb95b78dd-xtd2h",
      "instance": "RACCDB1",
      "pdb": "LABPDB",
      "databaseService": "labpdb_app",
      "service": "python-tasks"
    },
    "notes": {
      "healthy": true,
      "pod": "board-notes-558f6cb9fd-ccvk6",
      "instance": "RACCDB1",
      "databaseService": "labpdb_app",
      "pdb": "LABPDB",
      "service": "java-notes",
      "mode": "oracle"
    }
  },
  "checkedAt": "2026-10-14T23:38:07.779Z"
}
PASS: three Ready nodes, eight Ready app pods, both worker HTTP paths query Oracle LABPDB
Startup observations: racnode1-0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
10/14/2026 12:35:18 PM  WARNING:   oracommon   -     checkoserr     :OS command returned code : 1, returned error : no returned error and returned output : CRS-4640: Oracle High Availability Services is already active
CRS-4000: Command Start failed, or completed with errors.
10/14/2026 12:35:19 PM     INFO:  oramachine   -       setup        :Total time for setup() = [ 40.503 ] seconds
[FATAL] [INS-40401] Oracle Grid Infrastructure is already configured on the system.
Startup observations: racnode2-0
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
10/14/2026 11:35:01 PM  WARNING:   oracommon   -     checkoserr     :OS command returned code : 1, returned error : no returned error and returned output : CRS-4640: Oracle High Availability Services is already active
CRS-4000: Command Start failed, or completed with errors.
10/14/2026 11:35:02 PM     INFO:  oramachine   -       setup        :Total time for setup() = [ 36.174 ] seconds
```
