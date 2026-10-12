# RAC pod replacement: complete captured output

Actual maintenance on 11 October 2026. Pod2 was replaced first; Kubernetes replacement succeeded but Oracle recovery required the documented manual GI restoration. The first SQL gate fired before ASM/DB startup completed; the later full acceptance passed. No forced deletion or storage reinitialization was used. See [the workbook](RAC-POD-EXERCISES.md) for commands, interpretation and limits. Full object JSON is retained where captured; it includes Secret references, never Secret payloads. Tabs are expanded.

## Normal deletion and failed immediate SQL gate

Evidence: `logs/ssh-ocne-cp-Exercise-RAC-Pod-Replacement-20261011-194752.txt`.

<details>
<summary>Complete command output</summary>

```text

UTC 2026-10-11T23:47:52.630622+00:00 $ kubectl exec -n rac racnode1-0 -- cat /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code
0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:47:52.758853+00:00 $ kubectl get racdatabase rac19c -n rac -o json
{
    "apiVersion": "database.oracle.com/v4",
    "kind": "RacDatabase",
    "metadata": {
        "annotations": {
            "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"database.oracle.com/v4\",\"kind\":\"RacDatabase\",\"metadata\":{\"annotations\":{},\"name\":\"rac19c\",\"namespace\":\"rac\"},\"spec\":{\"asmDiskGroupDetails\":[{\"disks\":[\"/dev/disk/by-partlabel/ocne-rac-asm01\",\"/dev/disk/by-partlabel/ocne-rac-asm02\"],\"name\":\"DATA\",\"redundancy\":\"EXTERNAL\",\"type\":\"CRSDG\"}],\"configParams\":{\"cpuCount\":4,\"dbBase\":\"/u01/app/oracle\",\"dbHome\":\"/u01/app/oracle/product/19c/dbhome_1\",\"dbName\":\"RACCDB\",\"dbSwZipFile\":\"oracle-dbhome-19.32.zip\",\"gridBase\":\"/u01/app/grid\",\"gridHome\":\"/u01/app/19c/grid\",\"gridSwZipFile\":\"oracle-gridhome-19.32.zip\",\"hostSwStageLocation\":\"/scratch/software/stage/19c/19.32-gold\",\"inventory\":\"/u01/app/oraInventory\",\"pdbName\":\"LABPDB\",\"pgaSize\":\"2G\",\"processes\":500,\"sgaSize\":\"3G\"},\"dbSecret\":{\"encryptionType\":\"pkeyutl\",\"keyFileName\":\"key.pem\",\"name\":\"rac-db-password\",\"pkeyopt\":\"rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256\",\"pwdFileName\":\"pwdfile.enc\"},\"envVars\":[{\"name\":\"ORACLE_PDB_NAME\",\"value\":\"LABPDB\"},{\"name\":\"LOG_DIR\",\"value\":\"/tmp/orod\"},{\"name\":\"TOTAL_MEMORY\",\"value\":\"16384\"}],\"image\":\"docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d\",\"imagePullPolicy\":\"IfNotPresent\",\"instanceDetails\":{\"baseLsnrTargetPort\":31522,\"baseOnsTargetPort\":30200,\"nodeCount\":2,\"privateIPDetails\":[{\"interface\":\"ens1\",\"name\":\"macvlan-conf1\"},{\"interface\":\"ens2\",\"name\":\"macvlan-conf2\"}],\"racHostSwLocation\":\"/scratch/rac/cluster01\",\"racNodeName\":\"racnode\",\"workerNodeSelector\":{\"raccluster\":\"raccluster01\"}},\"resources\":{\"limits\":{\"cpu\":\"4\",\"memory\":\"16Gi\"},\"requests\":{\"cpu\":\"4\",\"memory\":\"16Gi\"}},\"scanSvcName\":\"racnode-scan\",\"scanSvcTargetPort\":31521,\"securityContext\":{\"sysctls\":[{\"name\":\"kernel.shmall\",\"value\":\"2097152\"},{\"name\":\"kernel.shmmax\",\"value\":\"8589934592\"},{\"name\":\"kernel.shmmni\",\"value\":\"4096\"},{\"name\":\"kernel.sem\",\"value\":\"250 32000 100 128\"},{\"name\":\"net.ipv4.conf.all.rp_filter\",\"value\":\"2\"}]},\"serviceDetails\":{\"name\":\"labpdb\"},\"sshKeySecret\":{\"name\":\"rac-ssh-key\",\"privKeySecretName\":\"ssh-privkey\",\"pubKeySecretName\":\"ssh-pubkey\"}}}\n",
            "racdatabases.database.oracle.com/old-spec": "{\"instanceDetails\":{\"nodeCount\":2,\"racHostSwLocation\":\"/scratch/rac/cluster01\",\"racNodeName\":\"racnode\",\"baseOnsTargetPort\":30200,\"baseLsnrTargetPort\":31522,\"privateIPDetails\":[{\"name\":\"macvlan-conf1\",\"interface\":\"ens1\"},{\"name\":\"macvlan-conf2\",\"interface\":\"ens2\"}],\"workerNodeSelector\":{\"raccluster\":\"raccluster01\"}},\"configParams\":{\"gridHome\":\"/u01/app/19c/grid\",\"dbHome\":\"/u01/app/oracle/product/19c/dbhome_1\",\"gridBase\":\"/u01/app/grid\",\"dbBase\":\"/u01/app/oracle\",\"inventory\":\"/u01/app/oraInventory\",\"gridSwZipFile\":\"oracle-gridhome-19.32.zip\",\"dbSwZipFile\":\"oracle-dbhome-19.32.zip\",\"cpuCount\":4,\"sgaSize\":\"3G\",\"pgaSize\":\"2G\",\"processes\":500,\"dbName\":\"RACCDB\",\"pdbName\":\"LABPDB\",\"dbCharSet\":\"AL32UTF8\",\"swMountLocation\":\"/u01\",\"hostSwStageLocation\":\"/scratch/software/stage/19c/19.32-gold\"},\"asmDiskGroupDetails\":[{\"name\":\"DATA\",\"redundancy\":\"EXTERNAL\",\"type\":\"CRSDG\",\"disks\":[\"/dev/disk/by-partlabel/ocne-rac-asm01\",\"/dev/disk/by-partlabel/ocne-rac-asm02\"]},{\"name\":\"DATA\",\"type\":\"DBDATAFILESDG\",\"disks\":null},{\"name\":\"DATA\",\"type\":\"DBRECOVERY\",\"disks\":null}],\"envVars\":[{\"name\":\"ORACLE_PDB_NAME\",\"value\":\"LABPDB\"},{\"name\":\"LOG_DIR\",\"value\":\"/tmp/orod\"},{\"name\":\"TOTAL_MEMORY\",\"value\":\"16384\"}],\"image\":\"docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d\",\"sshKeySecret\":{\"name\":\"rac-ssh-key\",\"keyMountLocation\":\"/mnt/.ssh\",\"privKeySecretName\":\"ssh-privkey\",\"pubKeySecretName\":\"ssh-pubkey\"},\"imagePullPolicy\":\"IfNotPresent\",\"scanSvcName\":\"racnode-scan\",\"securityContext\":{\"sysctls\":[{\"name\":\"kernel.shmall\",\"value\":\"2097152\"},{\"name\":\"kernel.shmmax\",\"value\":\"8589934592\"},{\"name\":\"kernel.shmmni\",\"value\":\"4096\"},{\"name\":\"kernel.sem\",\"value\":\"250 32000 100 128\"},{\"name\":\"net.ipv4.conf.all.rp_filter\",\"value\":\"2\"}]},\"scanSvcTargetPort\":31521,\"dbSecret\":{\"name\":\"rac-db-password\",\"keyFileName\":\"key.pem\",\"pwdFileName\":\"pwdfile.enc\",\"pwdFileMountLocation\":\"/mnt/.dbsecrets\",\"keyFileMountLocation\":\"/mnt/.dbsecrets\",\"encryptionType\":\"pkeyutl\",\"pkeyopt\":\"rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256\"},\"serviceDetails\":{\"name\":\"labpdb\"},\"resources\":{\"limits\":{\"cpu\":\"4\",\"memory\":\"16Gi\"},\"requests\":{\"cpu\":\"4\",\"memory\":\"16Gi\"}}}"
        },
        "creationTimestamp": "2026-10-11T02:14:00Z",
        "finalizers": [
            "database.oracle.com/racdatabasefinalizer"
        ],
        "generation": 3,
        "name": "rac19c",
        "namespace": "rac",
        "resourceVersion": "388625",
        "uid": "6be9de9e-f884-4b82-848b-52eadd7213d1"
    },
    "spec": {
        "asmDiskGroupDetails": [
            {
                "disks": [
                    "/dev/disk/by-partlabel/ocne-rac-asm01",
                    "/dev/disk/by-partlabel/ocne-rac-asm02"
                ],
                "name": "DATA",
                "redundancy": "EXTERNAL",
                "type": "CRSDG"
            }
        ],
        "configParams": {
            "cpuCount": 4,
            "dbBase": "/u01/app/oracle",
            "dbHome": "/u01/app/oracle/product/19c/dbhome_1",
            "dbName": "RACCDB",
            "dbSwZipFile": "oracle-dbhome-19.32.zip",
            "gridBase": "/u01/app/grid",
            "gridHome": "/u01/app/19c/grid",
            "gridSwZipFile": "oracle-gridhome-19.32.zip",
            "hostSwStageLocation": "/scratch/software/stage/19c/19.32-gold",
            "inventory": "/u01/app/oraInventory",
            "pdbName": "LABPDB",
            "pgaSize": "2G",
            "processes": 500,
            "sgaSize": "3G",
            "swMountLocation": "/u01"
        },
        "dbSecret": {
            "encryptionType": "pkeyutl",
            "keyFileMountLocation": "/mnt/.dbsecrets",
            "keyFileName": "key.pem",
            "name": "rac-db-password",
            "pkeyopt": "rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256",
            "pwdFileMountLocation": "/mnt/.dbsecrets",
            "pwdFileName": "pwdfile.enc"
        },
        "envVars": [
            {
                "name": "ORACLE_PDB_NAME",
                "value": "LABPDB"
            },
            {
                "name": "LOG_DIR",
                "value": "/tmp/orod"
            },
            {
                "name": "TOTAL_MEMORY",
                "value": "16384"
            }
        ],
        "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
        "imagePullPolicy": "IfNotPresent",
        "instanceDetails": {
            "baseLsnrTargetPort": 31522,
            "baseOnsTargetPort": 30200,
            "nodeCount": 2,
            "privateIPDetails": [
                {
                    "interface": "ens1",
                    "name": "macvlan-conf1"
                },
                {
                    "interface": "ens2",
                    "name": "macvlan-conf2"
                }
            ],
            "racHostSwLocation": "/scratch/rac/cluster01",
            "racNodeName": "racnode",
            "workerNodeSelector": {
                "raccluster": "raccluster01"
            }
        },
        "resources": {
            "limits": {
                "cpu": "4",
                "memory": "16Gi"
            },
            "requests": {
                "cpu": "4",
                "memory": "16Gi"
            }
        },
        "scanSvcName": "racnode-scan",
        "scanSvcTargetPort": 31521,
        "securityContext": {
            "sysctls": [
                {
                    "name": "kernel.shmall",
                    "value": "2097152"
                },
                {
                    "name": "kernel.shmmax",
                    "value": "8589934592"
                },
                {
                    "name": "kernel.shmmni",
                    "value": "4096"
                },
                {
                    "name": "kernel.sem",
                    "value": "250 32000 100 128"
                },
                {
                    "name": "net.ipv4.conf.all.rp_filter",
                    "value": "2"
                }
            ]
        },
        "serviceDetails": {
            "name": "labpdb"
        },
        "sshKeySecret": {
            "keyMountLocation": "/mnt/.ssh",
            "name": "rac-ssh-key",
            "privKeySecretName": "ssh-privkey",
            "pubKeySecretName": "ssh-pubkey"
        }
    },
    "status": {
        "asmDiskGroups": [
            {
                "disks": [
                    {
                        "name": "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "sizeInGb": 49,
                        "valid": true
                    },
                    {
                        "name": "/dev/disk/by-partlabel/ocne-rac-asm02",
                        "sizeInGb": 49,
                        "valid": true
                    }
                ],
                "name": "DATA",
                "redundancy": "EXTERN",
                "type": "CRSDG"
            }
        ],
        "clientEtcHost": [
            "192.168.77.12    racnode1-0.rac.svc.cluster.local racnode1-0-vip.rac.svc.cluster.local    racnode-scan.rac.svc.cluster.local",
            "192.168.77.13    racnode2-0.rac.svc.cluster.local racnode2-0-vip.rac.svc.cluster.local    racnode-scan.rac.svc.cluster.local"
        ],
        "conditions": [
            {
                "lastTransitionTime": "2026-10-11T23:47:30Z",
                "message": "no reconcile errors",
                "observedGeneration": 3,
                "reason": "LastReconcileCycleCompleted",
                "status": "True",
                "type": "ReconcileComplete"
            },
            {
                "lastTransitionTime": "2026-10-11T02:14:16Z",
                "message": "RAC pods pending: [racnode1-0]",
                "observedGeneration": 1,
                "reason": "LastReconcileCycleWaiting",
                "status": "True",
                "type": "ReconcileWaiting"
            }
        ],
        "configParams": {
            "dbBase": "/u01/app/oracle",
            "dbHome": "/u01/app/oracle/product/19c/dbhome_1",
            "dbName": "RACCDB",
            "gridBase": "/u01/app/grid",
            "gridHome": "/u01/app/19c/grid",
            "inventory": "/u01/app/oraInventory"
        },
        "connectString": "racnode-scan:1521/RACCDB",
        "dbSecret": {
            "encryptionType": "pkeyutl",
            "keyFileMountLocation": "/mnt/.dbsecrets",
            "keyFileName": "key.pem",
            "name": "rac-db-password",
            "pkeyopt": "rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256",
            "pwdFileMountLocation": "/mnt/.dbsecrets",
            "pwdFileName": "pwdfile.enc"
        },
        "dbState": "OPEN",
        "externalConnectString": "racnode-scan.rac.svc.cluster.local:31521/labpdb",
        "observedGeneration": 3,
        "pdbConnectString": "racnode-scan:1521/ORCLPDB",
        "racNodes": [
            {
                "name": "racnode1-0",
                "nodeDetails": {
                    "InstanceState": "OPEN",
                    "PodState": "AVAILABLE",
                    "clusterState": "HEALTHY",
                    "mountedDevices": [
                        "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "/dev/disk/by-partlabel/ocne-rac-asm02"
                    ],
                    "state": "AVAILABLE",
                    "vipDetails": {
                        "Name": "racnode1-0-vip"
                    }
                }
            },
            {
                "name": "racnode2-0",
                "nodeDetails": {
                    "InstanceState": "OPEN",
                    "PodState": "AVAILABLE",
                    "clusterState": "HEALTHY",
                    "mountedDevices": [
                        "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "/dev/disk/by-partlabel/ocne-rac-asm02"
                    ],
                    "state": "AVAILABLE",
                    "vipDetails": {
                        "Name": "racnode2-0-vip"
                    }
                }
            }
        ],
        "releaseUpdate": "19.32.0.0.0",
        "role": "PRIMARY",
        "scanSvcName": "racnode-scan",
        "serviceDetails": {
            "name": "labpdb",
            "svcState": "prcr-1001 : resource ora.raccdb.labpdb.svc does not exist"
        },
        "state": "AVAILABLE"
    }
}
Exit code: 0

UTC 2026-10-11T23:47:52.817866+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

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

UTC 2026-10-11T23:47:53.163000+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:47:53.911189+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h   10.244.1.9   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          21h   10.244.2.9   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:47:53.974486+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:47:54.240933+00:00 $ kubectl -n rac get pod racnode2-0 -o json
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "annotations": {
            "database.oracle.com/rac-configmap-hash": "bfd74fa7cef62fb8f9af88a0c1928697ed164fb54a2d14584bf2eb1e64c36597",
            "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"cbr0\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.244.2.9\"\n    ],\n    \"mac\": \"16:66:bd:cd:7a:b3\",\n    \"default\": true,\n    \"dns\": {},\n    \"gateway\": [\n        \"10.244.2.1\"\n    ]\n},{\n    \"name\": \"rac/macvlan-conf1\",\n    \"interface\": \"ens1\",\n    \"ips\": [\n        \"192.168.78.121\"\n    ],\n    \"mac\": \"a2:af:c0:f6:58:bd\",\n    \"dns\": {}\n},{\n    \"name\": \"rac/macvlan-conf2\",\n    \"interface\": \"ens2\",\n    \"ips\": [\n        \"192.168.79.121\"\n    ],\n    \"mac\": \"16:25:d7:82:59:0d\",\n    \"dns\": {}\n}]",
            "k8s.v1.cni.cncf.io/networks": "[{\"interface\":\"ens1\",\"ips\":[\"192.168.78.121/24\"],\"name\":\"macvlan-conf1\",\"namespace\":\"rac\"},{\"interface\":\"ens2\",\"ips\":[\"192.168.79.121/24\"],\"name\":\"macvlan-conf2\",\"namespace\":\"rac\"}]"
        },
        "creationTimestamp": "2026-10-11T02:14:16Z",
        "generateName": "racnode2-",
        "labels": {
            "app": "oracle-database-operator",
            "apps.kubernetes.io/pod-index": "0",
            "controller-revision-hash": "racnode2-5c6c49d448",
            "database.oracle.com/component": "RAC",
            "database.oracle.com/managed-by": "racdatabase-controller",
            "database.oracle.com/name": "rac19c",
            "statefulset.kubernetes.io/pod-name": "racnode2-0"
        },
        "name": "racnode2-0",
        "namespace": "rac",
        "ownerReferences": [
            {
                "apiVersion": "apps/v1",
                "blockOwnerDeletion": true,
                "controller": true,
                "kind": "StatefulSet",
                "name": "racnode2",
                "uid": "36a782cc-eb79-4e70-824c-a8254db93474"
            }
        ],
        "resourceVersion": "315461",
        "uid": "fb9bdc6d-2737-4291-bedd-121e30724c0a"
    },
    "spec": {
        "affinity": {
            "nodeAffinity": {
                "requiredDuringSchedulingIgnoredDuringExecution": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {
                                    "key": "raccluster",
                                    "operator": "In",
                                    "values": [
                                        "raccluster01"
                                    ]
                                },
                                {
                                    "key": "kubernetes.io/hostname",
                                    "operator": "In",
                                    "values": [
                                        "ocne-w2.lab.test"
                                    ]
                                }
                            ]
                        }
                    ]
                }
            }
        },
        "containers": [
            {
                "command": [
                    "/usr/sbin/init"
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode2-0",
                "ports": [
                    {
                        "containerPort": 1521,
                        "name": "tcp-1521jt4kj",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 1522,
                        "name": "tcp-1522w42vh",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 22,
                        "name": "tcp-22tvh6s",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 6200,
                        "name": "tcp-6200vbkq2",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 8080,
                        "name": "tcp-8080bqv2f",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 31523,
                        "name": "tcp-31523v97ws",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 30201,
                        "name": "tcp-302019kldq",
                        "protocol": "TCP"
                    }
                ],
                "readinessProbe": {
                    "failureThreshold": 3,
                    "initialDelaySeconds": 180,
                    "periodSeconds": 5,
                    "successThreshold": 1,
                    "tcpSocket": {
                        "port": 31522
                    },
                    "timeoutSeconds": 1
                },
                "resources": {
                    "limits": {
                        "cpu": "4",
                        "hugepages-2Mi": "3Gi",
                        "memory": "16Gi"
                    },
                    "requests": {
                        "cpu": "4",
                        "hugepages-2Mi": "3Gi",
                        "memory": "16Gi"
                    }
                },
                "securityContext": {
                    "capabilities": {
                        "add": [
                            "NET_ADMIN",
                            "SYS_NICE",
                            "SYS_RESOURCE",
                            "AUDIT_WRITE",
                            "NET_RAW",
                            "AUDIT_CONTROL",
                            "SYS_CHROOT"
                        ]
                    },
                    "privileged": false
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeDevices": [
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "name": "asm-pvc-16e0716b-rac19c"
                    },
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm02",
                        "name": "asm-pvc-ee86c2c9-rac19c"
                    }
                ],
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode2-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode2-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode2-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode2-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode2-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode2-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode2-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-lbtsk",
                        "readOnly": true
                    }
                ]
            }
        ],
        "dnsPolicy": "ClusterFirst",
        "enableServiceLinks": true,
        "hostname": "racnode2-0",
        "initContainers": [
            {
                "command": [
                    "/bin/bash",
                    "-c",
                    "\n\t\tsysctl -w net.ipv4.conf.all.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.default.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens1.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens2.rp_filter=2 || true \u0026\u0026\n\n\t\tIP1=$(ip addr show ens1 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\t\tIP2=$(ip addr show ens2 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\n\t\t# Write environment file (overwrite + append)\n\t\tif [ -n \"$IP1\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP1=$IP1\" \u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t\tif [ -n \"$IP2\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP2=$IP2\" \u003e\u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t/bin/true"
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode2-init1",
                "resources": {},
                "securityContext": {
                    "privileged": true,
                    "runAsUser": 0
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode2-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode2-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode2-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode2-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode2-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode2-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode2-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-lbtsk",
                        "readOnly": true
                    }
                ]
            }
        ],
        "nodeName": "ocne-w2.lab.test",
        "preemptionPolicy": "PreemptLowerPriority",
        "priority": 0,
        "restartPolicy": "Always",
        "schedulerName": "default-scheduler",
        "securityContext": {
            "sysctls": [
                {
                    "name": "kernel.shmall",
                    "value": "786432"
                },
                {
                    "name": "kernel.shmmax",
                    "value": "3221225472"
                },
                {
                    "name": "kernel.shmmni",
                    "value": "4096"
                },
                {
                    "name": "kernel.sem",
                    "value": "250 32000 100 128"
                },
                {
                    "name": "net.ipv4.conf.all.rp_filter",
                    "value": "2"
                },
                {
                    "name": "net.ipv4.conf.default.rp_filter",
                    "value": "2"
                }
            ]
        },
        "serviceAccount": "default",
        "serviceAccountName": "default",
        "subdomain": "racnode",
        "terminationGracePeriodSeconds": 30,
        "tolerations": [
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/not-ready",
                "operator": "Exists",
                "tolerationSeconds": 300
            },
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/unreachable",
                "operator": "Exists",
                "tolerationSeconds": 300
            }
        ],
        "volumes": [
            {
                "name": "racnode2-ssh-secretmap-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-ssh-key"
                }
            },
            {
                "emptyDir": {
                    "medium": "Memory"
                },
                "name": "racnode2-oradshm-vol"
            },
            {
                "name": "racnode2-dbsecret-pwd-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-db-password"
                }
            },
            {
                "configMap": {
                    "defaultMode": 420,
                    "name": "racnode2rac19c-cmap"
                },
                "name": "racnode2-oradata-envfile"
            },
            {
                "hostPath": {
                    "path": "/scratch/rac/cluster01/racnode2",
                    "type": ""
                },
                "name": "racnode2-oradata-sw-vol"
            },
            {
                "hostPath": {
                    "path": "/scratch/software/stage/19c/19.32-gold",
                    "type": ""
                },
                "name": "racnode2-oradata-swstage-vol"
            },
            {
                "name": "asm-pvc-16e0716b-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-16e0716b-rac19c"
                }
            },
            {
                "name": "asm-pvc-ee86c2c9-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-ee86c2c9-rac19c"
                }
            },
            {
                "emptyDir": {},
                "name": "racnode2-oradata-envfile-writable"
            },
            {
                "name": "kube-api-access-lbtsk",
                "projected": {
                    "defaultMode": 420,
                    "sources": [
                        {
                            "serviceAccountToken": {
                                "expirationSeconds": 3607,
                                "path": "token"
                            }
                        },
                        {
                            "configMap": {
                                "items": [
                                    {
                                        "key": "ca.crt",
                                        "path": "ca.crt"
                                    }
                                ],
                                "name": "kube-root-ca.crt"
                            }
                        },
                        {
                            "downwardAPI": {
                                "items": [
                                    {
                                        "fieldRef": {
                                            "apiVersion": "v1",
                                            "fieldPath": "metadata.namespace"
                                        },
                                        "path": "namespace"
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        ]
    },
    "status": {
        "conditions": [
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:22Z",
                "status": "True",
                "type": "PodReadyToStartContainers"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:22Z",
                "status": "True",
                "type": "Initialized"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T14:19:51Z",
                "status": "True",
                "type": "Ready"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T14:19:51Z",
                "status": "True",
                "type": "ContainersReady"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:21Z",
                "status": "True",
                "type": "PodScheduled"
            }
        ],
        "containerStatuses": [
            {
                "containerID": "cri-o://63714943e672899a7b5ff649bbb0fbf22291b9fec202e0a0beac3d60e81cf2f6",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode2-0",
                "ready": true,
                "restartCount": 0,
                "started": true,
                "state": {
                    "running": {
                        "startedAt": "2026-10-11T02:14:22Z"
                    }
                }
            }
        ],
        "hostIP": "192.168.77.13",
        "hostIPs": [
            {
                "ip": "192.168.77.13"
            }
        ],
        "initContainerStatuses": [
            {
                "containerID": "cri-o://a0c2e26534369ffd86d4c67f218e8b7bd8834ab00f9b2fde6ddb7ca5aefb5216",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode2-init1",
                "ready": true,
                "restartCount": 0,
                "started": false,
                "state": {
                    "terminated": {
                        "containerID": "cri-o://a0c2e26534369ffd86d4c67f218e8b7bd8834ab00f9b2fde6ddb7ca5aefb5216",
                        "exitCode": 0,
                        "finishedAt": "2026-10-11T02:14:22Z",
                        "reason": "Completed",
                        "startedAt": "2026-10-11T02:14:22Z"
                    }
                }
            }
        ],
        "phase": "Running",
        "podIP": "10.244.2.9",
        "podIPs": [
            {
                "ip": "10.244.2.9"
            }
        ],
        "qosClass": "Burstable",
        "startTime": "2026-10-11T02:14:21Z"
    }
}
Exit code: 0

UTC 2026-10-11T23:47:54.303115+00:00 $ kubectl exec -n rac racnode2-0 -- cmp /etc/oracle/olr.loc /u01/app/grid/.etcoraclebackup/oracle/olr.loc
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:47:54.416466+00:00 $ kubectl exec -n rac racnode2-0 -- cmp /etc/oracle/ocr.loc /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0
SCENARIO S08: normal replacement of racnode2-0; old UID=fb9bdc6d-2737-4291-bedd-121e30724c0a

UTC 2026-10-11T23:47:54.534932+00:00 $ kubectl -n rac delete pod racnode2-0 --grace-period=120 --wait=false
pod "racnode2-0" deleted
Exit code: 0
2026-10-11T23:47:54.688127+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:48:09.774767+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:48:24.853819+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:48:39.939531+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:48:55.018597+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:49:10.104005+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:49:25.180056+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:49:40.259793+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Running Ready=True deleting=True
2026-10-11T23:49:55.338084+00:00 racnode2-0 fb9bdc6d-2737-4291-bedd-121e30724c0a Failed Ready=False deleting=True
2026-10-11T23:50:10.415770+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:50:25.504218+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:50:40.586151+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:50:55.660080+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:51:10.729078+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:51:25.849658+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:51:40.930316+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:51:56.003280+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:52:11.085233+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:52:26.167349+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:52:41.269866+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:52:56.344786+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:53:11.499461+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:53:26.585076+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:53:41.709313+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:53:56.799640+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:54:11.879941+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:54:26.951438+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:54:42.019952+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=False deleting=False
2026-10-11T23:54:57.103182+00:00 racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d Running Ready=True deleting=False

UTC 2026-10-11T23:54:57.103245+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE    IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h    10.244.1.9    ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          5m2s   10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:54:57.169229+00:00 $ kubectl exec -n rac racnode2-0 -- /u01/app/19c/grid/bin/crsctl check crs
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:54:57.371784+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 LABPDB                                                               READ WRITE

declare n number; begin select count(*) into n from gv$instance where status='OPEN' and database_status='ACTIVE'; if n<>2 then raise_application_error(-20001,'Both instances must be open'); end if; end;
*
ERROR at line 1:
ORA-20001: Both instances must be open
ORA-06512: at line 1


Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
command terminated with exit code 1
Exit code: 1
Traceback (most recent call last):
  File "<stdin>", line 62, in <module>
  File "<stdin>", line 16, in healthy
  File "<stdin>", line 14, in sql
  File "<stdin>", line 10, in k
  File "<stdin>", line 8, in run
RuntimeError: Command failed; review captured output
```

</details>

## First guarded recovery attempt: stopped without changing GI

Evidence: `logs/ssh-ocne-cp-Recover-RAC-Replaced-Node2-20261011-195226.txt`.

<details>
<summary>Complete command output</summary>

```text
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
command terminated with exit code 1
```

</details>

## Worker2 recovery labels

Evidence: `logs/ssh-ocne-w2-Repair-RAC-Recovery-Labels-20261011-195332.txt`.

<details>
<summary>Complete command output</summary>

```text
drwx------. 3 root root  system_u:object_r:container_file_t:s0            20 Oct 11 19:38 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0:c589,c809 151 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0:c589,c809  96 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc
/scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc    system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/setasmgid from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/ocr.loc from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/ocr.loc.orig from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc.orig from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/lastgasp from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/lastgasp/cssmonit_racnode2-0.lgl from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/lastgasp/cssagent_racnode2-0.lgl from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/maps from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/oprocd from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/oprocd/check from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/oprocd/stop from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/oprocd/fatal from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0 from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/grid from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/grid/cssfatal from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/root from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/root/crsstart from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/root/ohasdrun from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/root/ohasdinitpid from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/scls_scr/racnode2-0/root/ohasdstr from system_u:object_r:container_file_t:s0:c589,c809 to system_u:object_r:container_file_t:s0
drwx------. 3 root root  system_u:object_r:container_file_t:s0  20 Oct 11 19:38 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0 151 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0  96 Oct 10 22:39 /scratch/rac/cluster01/racnode2/app/grid/.etcoraclebackup/oracle/olr.loc
```

</details>

## Worker1 recovery labels

Evidence: `logs/ssh-ocne-w1-Repair-RAC-Recovery-Labels-20261011-195332.txt`.

<details>
<summary>Complete command output</summary>

```text
drwx------. 3 root root  system_u:object_r:container_file_t:s0            20 Oct 11 19:38 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0:c223,c536 151 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0:c223,c536  96 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc
/scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc    system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/setasmgid from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/ocr.loc from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/ocr.loc.orig from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc.orig from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/lastgasp from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/lastgasp/cssmonit_racnode1-0.lgl from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/lastgasp/cssagent_racnode1-0.lgl from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/maps from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/oprocd from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/oprocd/check from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/oprocd/stop from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/oprocd/fatal from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0 from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/grid from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/grid/cssfatal from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/root from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/root/crsstart from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/root/ohasdrun from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/root/ohasdinitpid from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
Relabeled /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/scls_scr/racnode1-0/root/ohasdstr from system_u:object_r:container_file_t:s0:c223,c536 to system_u:object_r:container_file_t:s0
drwx------. 3 root root  system_u:object_r:container_file_t:s0  20 Oct 11 19:38 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup
drwxr-xr-x. 6 root 54321 system_u:object_r:container_file_t:s0 151 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle
-rw-r--r--. 1 root 54321 system_u:object_r:container_file_t:s0  96 Oct 10 22:34 /scratch/rac/cluster01/racnode1/app/grid/.etcoraclebackup/oracle/olr.loc
```

</details>

## Node2 assisted GI recovery

Evidence: `logs/ssh-ocne-cp-Recover-RAC-Replaced-Node2-20261011-195349.txt`.

<details>
<summary>Complete command output</summary>

```text
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Using configuration parameter file: /u01/app/19c/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/grid/crsdata/racnode2-0/crsconfig/crsupdate_osfiles_racnode2-0_2026-10-11_11-53-49PM.log
Redirecting to /bin/systemctl restart rsyslog.service
2026/10/11 23:53:51 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
CRS-4123: Oracle High Availability Services has been started.
```

</details>

## Full post-recovery acceptance

Evidence: `logs/ssh-ocne-cp-Verify-RAC-Database-20261011-195602.txt`.

<details>
<summary>Complete command output</summary>

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
racnode1-0  1
racnode2-0  2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    89616                0           89616              0             Y  DATA/
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

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


NAME      OPEN_MODE        DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 PDB$SEED                                                             READ ONLY
     1 LABPDB                                                               READ WRITE
     2 PDB$SEED                                                             READ ONLY
     2 LABPDB                                                               READ WRITE


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


    CON_ID   PATCH_ID ACTION          STATUS            DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
     1   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     1   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)
     3   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     3   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
racnode1-0  1
racnode2-0  2
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    89616                0           89616              0             Y  DATA/
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

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


NAME      OPEN_MODE        DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 PDB$SEED                                                             READ ONLY
     1 LABPDB                                                               READ WRITE
     2 PDB$SEED                                                             READ ONLY
     2 LABPDB                                                               READ WRITE


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


    CON_ID   PATCH_ID ACTION          STATUS            DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
     1   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     1   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)
     3   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     3   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

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
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Instance RACCDB1 is running on node racnode1-0 with online services labpdb_app. Instance status: Open.
Instance RACCDB2 is running on node racnode2-0 with online services labpdb_app. Instance status: Open.
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
```

</details>

## Node1 replacement and SQL acceptance

Evidence: `logs/ssh-ocne-cp-Exercise-RAC-Pod1-Replacement-20261011-195656.txt`.

<details>
<summary>Complete command output</summary>

```text

UTC 2026-10-11T23:56:56.526856+00:00 $ kubectl exec -n rac racnode1-0 -- cat /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code
0
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:56:56.680789+00:00 $ kubectl get racdatabase rac19c -n rac -o json
{
    "apiVersion": "database.oracle.com/v4",
    "kind": "RacDatabase",
    "metadata": {
        "annotations": {
            "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"database.oracle.com/v4\",\"kind\":\"RacDatabase\",\"metadata\":{\"annotations\":{},\"name\":\"rac19c\",\"namespace\":\"rac\"},\"spec\":{\"asmDiskGroupDetails\":[{\"disks\":[\"/dev/disk/by-partlabel/ocne-rac-asm01\",\"/dev/disk/by-partlabel/ocne-rac-asm02\"],\"name\":\"DATA\",\"redundancy\":\"EXTERNAL\",\"type\":\"CRSDG\"}],\"configParams\":{\"cpuCount\":4,\"dbBase\":\"/u01/app/oracle\",\"dbHome\":\"/u01/app/oracle/product/19c/dbhome_1\",\"dbName\":\"RACCDB\",\"dbSwZipFile\":\"oracle-dbhome-19.32.zip\",\"gridBase\":\"/u01/app/grid\",\"gridHome\":\"/u01/app/19c/grid\",\"gridSwZipFile\":\"oracle-gridhome-19.32.zip\",\"hostSwStageLocation\":\"/scratch/software/stage/19c/19.32-gold\",\"inventory\":\"/u01/app/oraInventory\",\"pdbName\":\"LABPDB\",\"pgaSize\":\"2G\",\"processes\":500,\"sgaSize\":\"3G\"},\"dbSecret\":{\"encryptionType\":\"pkeyutl\",\"keyFileName\":\"key.pem\",\"name\":\"rac-db-password\",\"pkeyopt\":\"rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256\",\"pwdFileName\":\"pwdfile.enc\"},\"envVars\":[{\"name\":\"ORACLE_PDB_NAME\",\"value\":\"LABPDB\"},{\"name\":\"LOG_DIR\",\"value\":\"/tmp/orod\"},{\"name\":\"TOTAL_MEMORY\",\"value\":\"16384\"}],\"image\":\"docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d\",\"imagePullPolicy\":\"IfNotPresent\",\"instanceDetails\":{\"baseLsnrTargetPort\":31522,\"baseOnsTargetPort\":30200,\"nodeCount\":2,\"privateIPDetails\":[{\"interface\":\"ens1\",\"name\":\"macvlan-conf1\"},{\"interface\":\"ens2\",\"name\":\"macvlan-conf2\"}],\"racHostSwLocation\":\"/scratch/rac/cluster01\",\"racNodeName\":\"racnode\",\"workerNodeSelector\":{\"raccluster\":\"raccluster01\"}},\"resources\":{\"limits\":{\"cpu\":\"4\",\"memory\":\"16Gi\"},\"requests\":{\"cpu\":\"4\",\"memory\":\"16Gi\"}},\"scanSvcName\":\"racnode-scan\",\"scanSvcTargetPort\":31521,\"securityContext\":{\"sysctls\":[{\"name\":\"kernel.shmall\",\"value\":\"2097152\"},{\"name\":\"kernel.shmmax\",\"value\":\"8589934592\"},{\"name\":\"kernel.shmmni\",\"value\":\"4096\"},{\"name\":\"kernel.sem\",\"value\":\"250 32000 100 128\"},{\"name\":\"net.ipv4.conf.all.rp_filter\",\"value\":\"2\"}]},\"serviceDetails\":{\"name\":\"labpdb\"},\"sshKeySecret\":{\"name\":\"rac-ssh-key\",\"privKeySecretName\":\"ssh-privkey\",\"pubKeySecretName\":\"ssh-pubkey\"}}}\n",
            "racdatabases.database.oracle.com/old-spec": "{\"instanceDetails\":{\"nodeCount\":2,\"racHostSwLocation\":\"/scratch/rac/cluster01\",\"racNodeName\":\"racnode\",\"baseOnsTargetPort\":30200,\"baseLsnrTargetPort\":31522,\"privateIPDetails\":[{\"name\":\"macvlan-conf1\",\"interface\":\"ens1\"},{\"name\":\"macvlan-conf2\",\"interface\":\"ens2\"}],\"workerNodeSelector\":{\"raccluster\":\"raccluster01\"}},\"configParams\":{\"gridHome\":\"/u01/app/19c/grid\",\"dbHome\":\"/u01/app/oracle/product/19c/dbhome_1\",\"gridBase\":\"/u01/app/grid\",\"dbBase\":\"/u01/app/oracle\",\"inventory\":\"/u01/app/oraInventory\",\"gridSwZipFile\":\"oracle-gridhome-19.32.zip\",\"dbSwZipFile\":\"oracle-dbhome-19.32.zip\",\"cpuCount\":4,\"sgaSize\":\"3G\",\"pgaSize\":\"2G\",\"processes\":500,\"dbName\":\"RACCDB\",\"pdbName\":\"LABPDB\",\"dbCharSet\":\"AL32UTF8\",\"swMountLocation\":\"/u01\",\"hostSwStageLocation\":\"/scratch/software/stage/19c/19.32-gold\"},\"asmDiskGroupDetails\":[{\"name\":\"DATA\",\"redundancy\":\"EXTERNAL\",\"type\":\"CRSDG\",\"disks\":[\"/dev/disk/by-partlabel/ocne-rac-asm01\",\"/dev/disk/by-partlabel/ocne-rac-asm02\"]},{\"name\":\"DATA\",\"type\":\"DBDATAFILESDG\",\"disks\":null},{\"name\":\"DATA\",\"type\":\"DBRECOVERY\",\"disks\":null}],\"envVars\":[{\"name\":\"ORACLE_PDB_NAME\",\"value\":\"LABPDB\"},{\"name\":\"LOG_DIR\",\"value\":\"/tmp/orod\"},{\"name\":\"TOTAL_MEMORY\",\"value\":\"16384\"}],\"image\":\"docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d\",\"sshKeySecret\":{\"name\":\"rac-ssh-key\",\"keyMountLocation\":\"/mnt/.ssh\",\"privKeySecretName\":\"ssh-privkey\",\"pubKeySecretName\":\"ssh-pubkey\"},\"imagePullPolicy\":\"IfNotPresent\",\"scanSvcName\":\"racnode-scan\",\"securityContext\":{\"sysctls\":[{\"name\":\"kernel.shmall\",\"value\":\"2097152\"},{\"name\":\"kernel.shmmax\",\"value\":\"8589934592\"},{\"name\":\"kernel.shmmni\",\"value\":\"4096\"},{\"name\":\"kernel.sem\",\"value\":\"250 32000 100 128\"},{\"name\":\"net.ipv4.conf.all.rp_filter\",\"value\":\"2\"}]},\"scanSvcTargetPort\":31521,\"dbSecret\":{\"name\":\"rac-db-password\",\"keyFileName\":\"key.pem\",\"pwdFileName\":\"pwdfile.enc\",\"pwdFileMountLocation\":\"/mnt/.dbsecrets\",\"keyFileMountLocation\":\"/mnt/.dbsecrets\",\"encryptionType\":\"pkeyutl\",\"pkeyopt\":\"rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256\"},\"serviceDetails\":{\"name\":\"labpdb\"},\"resources\":{\"limits\":{\"cpu\":\"4\",\"memory\":\"16Gi\"},\"requests\":{\"cpu\":\"4\",\"memory\":\"16Gi\"}}}"
        },
        "creationTimestamp": "2026-10-11T02:14:00Z",
        "finalizers": [
            "database.oracle.com/racdatabasefinalizer"
        ],
        "generation": 3,
        "name": "rac19c",
        "namespace": "rac",
        "resourceVersion": "389843",
        "uid": "6be9de9e-f884-4b82-848b-52eadd7213d1"
    },
    "spec": {
        "asmDiskGroupDetails": [
            {
                "disks": [
                    "/dev/disk/by-partlabel/ocne-rac-asm01",
                    "/dev/disk/by-partlabel/ocne-rac-asm02"
                ],
                "name": "DATA",
                "redundancy": "EXTERNAL",
                "type": "CRSDG"
            }
        ],
        "configParams": {
            "cpuCount": 4,
            "dbBase": "/u01/app/oracle",
            "dbHome": "/u01/app/oracle/product/19c/dbhome_1",
            "dbName": "RACCDB",
            "dbSwZipFile": "oracle-dbhome-19.32.zip",
            "gridBase": "/u01/app/grid",
            "gridHome": "/u01/app/19c/grid",
            "gridSwZipFile": "oracle-gridhome-19.32.zip",
            "hostSwStageLocation": "/scratch/software/stage/19c/19.32-gold",
            "inventory": "/u01/app/oraInventory",
            "pdbName": "LABPDB",
            "pgaSize": "2G",
            "processes": 500,
            "sgaSize": "3G",
            "swMountLocation": "/u01"
        },
        "dbSecret": {
            "encryptionType": "pkeyutl",
            "keyFileMountLocation": "/mnt/.dbsecrets",
            "keyFileName": "key.pem",
            "name": "rac-db-password",
            "pkeyopt": "rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256",
            "pwdFileMountLocation": "/mnt/.dbsecrets",
            "pwdFileName": "pwdfile.enc"
        },
        "envVars": [
            {
                "name": "ORACLE_PDB_NAME",
                "value": "LABPDB"
            },
            {
                "name": "LOG_DIR",
                "value": "/tmp/orod"
            },
            {
                "name": "TOTAL_MEMORY",
                "value": "16384"
            }
        ],
        "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
        "imagePullPolicy": "IfNotPresent",
        "instanceDetails": {
            "baseLsnrTargetPort": 31522,
            "baseOnsTargetPort": 30200,
            "nodeCount": 2,
            "privateIPDetails": [
                {
                    "interface": "ens1",
                    "name": "macvlan-conf1"
                },
                {
                    "interface": "ens2",
                    "name": "macvlan-conf2"
                }
            ],
            "racHostSwLocation": "/scratch/rac/cluster01",
            "racNodeName": "racnode",
            "workerNodeSelector": {
                "raccluster": "raccluster01"
            }
        },
        "resources": {
            "limits": {
                "cpu": "4",
                "memory": "16Gi"
            },
            "requests": {
                "cpu": "4",
                "memory": "16Gi"
            }
        },
        "scanSvcName": "racnode-scan",
        "scanSvcTargetPort": 31521,
        "securityContext": {
            "sysctls": [
                {
                    "name": "kernel.shmall",
                    "value": "2097152"
                },
                {
                    "name": "kernel.shmmax",
                    "value": "8589934592"
                },
                {
                    "name": "kernel.shmmni",
                    "value": "4096"
                },
                {
                    "name": "kernel.sem",
                    "value": "250 32000 100 128"
                },
                {
                    "name": "net.ipv4.conf.all.rp_filter",
                    "value": "2"
                }
            ]
        },
        "serviceDetails": {
            "name": "labpdb"
        },
        "sshKeySecret": {
            "keyMountLocation": "/mnt/.ssh",
            "name": "rac-ssh-key",
            "privKeySecretName": "ssh-privkey",
            "pubKeySecretName": "ssh-pubkey"
        }
    },
    "status": {
        "asmDiskGroups": [
            {
                "disks": [
                    {
                        "name": "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "sizeInGb": 49,
                        "valid": true
                    },
                    {
                        "name": "/dev/disk/by-partlabel/ocne-rac-asm02",
                        "sizeInGb": 49,
                        "valid": true
                    }
                ],
                "name": "DATA",
                "redundancy": "EXTERN",
                "type": "CRSDG"
            }
        ],
        "clientEtcHost": [
            "192.168.77.12    racnode1-0.rac.svc.cluster.local racnode1-0-vip.rac.svc.cluster.local    racnode-scan.rac.svc.cluster.local",
            "192.168.77.13    racnode2-0.rac.svc.cluster.local racnode2-0-vip.rac.svc.cluster.local    racnode-scan.rac.svc.cluster.local"
        ],
        "conditions": [
            {
                "lastTransitionTime": "2026-10-11T23:56:19Z",
                "message": "no reconcile errors",
                "observedGeneration": 3,
                "reason": "LastReconcileCycleCompleted",
                "status": "True",
                "type": "ReconcileComplete"
            },
            {
                "lastTransitionTime": "2026-10-11T02:14:16Z",
                "message": "RAC pods pending: [racnode1-0]",
                "observedGeneration": 1,
                "reason": "LastReconcileCycleWaiting",
                "status": "True",
                "type": "ReconcileWaiting"
            }
        ],
        "configParams": {
            "dbBase": "/u01/app/oracle",
            "dbHome": "/u01/app/oracle/product/19c/dbhome_1",
            "dbName": "RACCDB",
            "gridBase": "/u01/app/grid",
            "gridHome": "/u01/app/19c/grid",
            "inventory": "/u01/app/oraInventory"
        },
        "connectString": "racnode-scan:1521/RACCDB",
        "dbSecret": {
            "encryptionType": "pkeyutl",
            "keyFileMountLocation": "/mnt/.dbsecrets",
            "keyFileName": "key.pem",
            "name": "rac-db-password",
            "pkeyopt": "rsa_padding_mode:oaep;rsa_oaep_md:sha256;rsa_mgf1_md:sha256",
            "pwdFileMountLocation": "/mnt/.dbsecrets",
            "pwdFileName": "pwdfile.enc"
        },
        "dbState": "OPEN",
        "externalConnectString": "racnode-scan.rac.svc.cluster.local:31521/labpdb",
        "observedGeneration": 3,
        "pdbConnectString": "racnode-scan:1521/ORCLPDB",
        "racNodes": [
            {
                "name": "racnode1-0",
                "nodeDetails": {
                    "InstanceState": "OPEN",
                    "PodState": "AVAILABLE",
                    "clusterState": "HEALTHY",
                    "mountedDevices": [
                        "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "/dev/disk/by-partlabel/ocne-rac-asm02"
                    ],
                    "state": "AVAILABLE",
                    "vipDetails": {
                        "Name": "racnode1-0-vip"
                    }
                }
            },
            {
                "name": "racnode2-0",
                "nodeDetails": {
                    "InstanceState": "OPEN",
                    "PodState": "AVAILABLE",
                    "clusterState": "HEALTHY",
                    "mountedDevices": [
                        "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "/dev/disk/by-partlabel/ocne-rac-asm02"
                    ],
                    "state": "AVAILABLE",
                    "vipDetails": {
                        "Name": "racnode2-0-vip"
                    }
                }
            }
        ],
        "releaseUpdate": "19.32.0.0.0",
        "role": "PRIMARY",
        "scanSvcName": "racnode-scan",
        "serviceDetails": {
            "name": "labpdb",
            "svcState": "prcr-1001 : resource ora.raccdb.labpdb.svc does not exist"
        },
        "state": "AVAILABLE"
    }
}
Exit code: 0

UTC 2026-10-11T23:56:56.750432+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

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

UTC 2026-10-11T23:56:57.098164+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:56:57.968109+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE    IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          21h    10.244.1.9    ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          7m3s   10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-11T23:56:58.035777+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-11T23:56:58.574995+00:00 $ kubectl -n rac get pod racnode1-0 -o json
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "annotations": {
            "database.oracle.com/rac-configmap-hash": "e846a808193d5b3cf7ab3f4f150cec01e551b515fddd5d3b5826364bc79acf66",
            "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"cbr0\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.244.1.9\"\n    ],\n    \"mac\": \"02:ef:c7:1b:43:53\",\n    \"default\": true,\n    \"dns\": {},\n    \"gateway\": [\n        \"10.244.1.1\"\n    ]\n},{\n    \"name\": \"rac/macvlan-conf1\",\n    \"interface\": \"ens1\",\n    \"ips\": [\n        \"192.168.78.120\"\n    ],\n    \"mac\": \"4e:23:e2:a7:c4:8a\",\n    \"dns\": {}\n},{\n    \"name\": \"rac/macvlan-conf2\",\n    \"interface\": \"ens2\",\n    \"ips\": [\n        \"192.168.79.120\"\n    ],\n    \"mac\": \"2a:77:78:7e:4e:b4\",\n    \"dns\": {}\n}]",
            "k8s.v1.cni.cncf.io/networks": "[{\"interface\":\"ens1\",\"ips\":[\"192.168.78.120/24\"],\"name\":\"macvlan-conf1\",\"namespace\":\"rac\"},{\"interface\":\"ens2\",\"ips\":[\"192.168.79.120/24\"],\"name\":\"macvlan-conf2\",\"namespace\":\"rac\"}]"
        },
        "creationTimestamp": "2026-10-11T02:14:16Z",
        "generateName": "racnode1-",
        "labels": {
            "app": "oracle-database-operator",
            "apps.kubernetes.io/pod-index": "0",
            "controller-revision-hash": "racnode1-774b859879",
            "database.oracle.com/component": "RAC",
            "database.oracle.com/managed-by": "racdatabase-controller",
            "database.oracle.com/name": "rac19c",
            "statefulset.kubernetes.io/pod-name": "racnode1-0"
        },
        "name": "racnode1-0",
        "namespace": "rac",
        "ownerReferences": [
            {
                "apiVersion": "apps/v1",
                "blockOwnerDeletion": true,
                "controller": true,
                "kind": "StatefulSet",
                "name": "racnode1",
                "uid": "d3987707-1668-494f-885f-864301da3cb4"
            }
        ],
        "resourceVersion": "315468",
        "uid": "0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4"
    },
    "spec": {
        "affinity": {
            "nodeAffinity": {
                "requiredDuringSchedulingIgnoredDuringExecution": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {
                                    "key": "raccluster",
                                    "operator": "In",
                                    "values": [
                                        "raccluster01"
                                    ]
                                },
                                {
                                    "key": "kubernetes.io/hostname",
                                    "operator": "In",
                                    "values": [
                                        "ocne-w1.lab.test"
                                    ]
                                }
                            ]
                        }
                    ]
                }
            }
        },
        "containers": [
            {
                "command": [
                    "/usr/sbin/init"
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode1-0",
                "ports": [
                    {
                        "containerPort": 1521,
                        "name": "tcp-1521lv5bb",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 1522,
                        "name": "tcp-1522gtk9k",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 22,
                        "name": "tcp-22hct82",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 6200,
                        "name": "tcp-6200nbrd7",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 8080,
                        "name": "tcp-8080pmc4d",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 31522,
                        "name": "tcp-31522vggpw",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 30200,
                        "name": "tcp-30200k6cr8",
                        "protocol": "TCP"
                    }
                ],
                "readinessProbe": {
                    "failureThreshold": 3,
                    "initialDelaySeconds": 180,
                    "periodSeconds": 5,
                    "successThreshold": 1,
                    "tcpSocket": {
                        "port": 31522
                    },
                    "timeoutSeconds": 1
                },
                "resources": {
                    "limits": {
                        "cpu": "4",
                        "hugepages-2Mi": "3Gi",
                        "memory": "16Gi"
                    },
                    "requests": {
                        "cpu": "4",
                        "hugepages-2Mi": "3Gi",
                        "memory": "16Gi"
                    }
                },
                "securityContext": {
                    "capabilities": {
                        "add": [
                            "NET_ADMIN",
                            "SYS_NICE",
                            "SYS_RESOURCE",
                            "AUDIT_WRITE",
                            "NET_RAW",
                            "AUDIT_CONTROL",
                            "SYS_CHROOT"
                        ]
                    },
                    "privileged": false
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeDevices": [
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "name": "asm-pvc-16e0716b-rac19c"
                    },
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm02",
                        "name": "asm-pvc-ee86c2c9-rac19c"
                    }
                ],
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode1-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode1-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode1-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode1-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode1-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode1-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode1-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-fvzfp",
                        "readOnly": true
                    }
                ]
            }
        ],
        "dnsPolicy": "ClusterFirst",
        "enableServiceLinks": true,
        "hostname": "racnode1-0",
        "initContainers": [
            {
                "command": [
                    "/bin/bash",
                    "-c",
                    "\n\t\tsysctl -w net.ipv4.conf.all.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.default.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens1.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens2.rp_filter=2 || true \u0026\u0026\n\n\t\tIP1=$(ip addr show ens1 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\t\tIP2=$(ip addr show ens2 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\n\t\t# Write environment file (overwrite + append)\n\t\tif [ -n \"$IP1\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP1=$IP1\" \u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t\tif [ -n \"$IP2\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP2=$IP2\" \u003e\u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t/bin/true"
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode1-init1",
                "resources": {},
                "securityContext": {
                    "privileged": true,
                    "runAsUser": 0
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode1-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode1-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode1-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode1-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode1-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode1-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode1-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-fvzfp",
                        "readOnly": true
                    }
                ]
            }
        ],
        "nodeName": "ocne-w1.lab.test",
        "preemptionPolicy": "PreemptLowerPriority",
        "priority": 0,
        "restartPolicy": "Always",
        "schedulerName": "default-scheduler",
        "securityContext": {
            "sysctls": [
                {
                    "name": "kernel.shmall",
                    "value": "786432"
                },
                {
                    "name": "kernel.shmmax",
                    "value": "3221225472"
                },
                {
                    "name": "kernel.shmmni",
                    "value": "4096"
                },
                {
                    "name": "kernel.sem",
                    "value": "250 32000 100 128"
                },
                {
                    "name": "net.ipv4.conf.all.rp_filter",
                    "value": "2"
                },
                {
                    "name": "net.ipv4.conf.default.rp_filter",
                    "value": "2"
                }
            ]
        },
        "serviceAccount": "default",
        "serviceAccountName": "default",
        "subdomain": "racnode",
        "terminationGracePeriodSeconds": 30,
        "tolerations": [
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/not-ready",
                "operator": "Exists",
                "tolerationSeconds": 300
            },
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/unreachable",
                "operator": "Exists",
                "tolerationSeconds": 300
            }
        ],
        "volumes": [
            {
                "name": "racnode1-ssh-secretmap-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-ssh-key"
                }
            },
            {
                "emptyDir": {
                    "medium": "Memory"
                },
                "name": "racnode1-oradshm-vol"
            },
            {
                "name": "racnode1-dbsecret-pwd-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-db-password"
                }
            },
            {
                "configMap": {
                    "defaultMode": 420,
                    "name": "racnode1rac19c-cmap"
                },
                "name": "racnode1-oradata-envfile"
            },
            {
                "hostPath": {
                    "path": "/scratch/rac/cluster01/racnode1",
                    "type": ""
                },
                "name": "racnode1-oradata-sw-vol"
            },
            {
                "hostPath": {
                    "path": "/scratch/software/stage/19c/19.32-gold",
                    "type": ""
                },
                "name": "racnode1-oradata-swstage-vol"
            },
            {
                "name": "asm-pvc-16e0716b-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-16e0716b-rac19c"
                }
            },
            {
                "name": "asm-pvc-ee86c2c9-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-ee86c2c9-rac19c"
                }
            },
            {
                "emptyDir": {},
                "name": "racnode1-oradata-envfile-writable"
            },
            {
                "name": "kube-api-access-fvzfp",
                "projected": {
                    "defaultMode": 420,
                    "sources": [
                        {
                            "serviceAccountToken": {
                                "expirationSeconds": 3607,
                                "path": "token"
                            }
                        },
                        {
                            "configMap": {
                                "items": [
                                    {
                                        "key": "ca.crt",
                                        "path": "ca.crt"
                                    }
                                ],
                                "name": "kube-root-ca.crt"
                            }
                        },
                        {
                            "downwardAPI": {
                                "items": [
                                    {
                                        "fieldRef": {
                                            "apiVersion": "v1",
                                            "fieldPath": "metadata.namespace"
                                        },
                                        "path": "namespace"
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        ]
    },
    "status": {
        "conditions": [
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:22Z",
                "status": "True",
                "type": "PodReadyToStartContainers"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:22Z",
                "status": "True",
                "type": "Initialized"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T14:19:52Z",
                "status": "True",
                "type": "Ready"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T14:19:52Z",
                "status": "True",
                "type": "ContainersReady"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T02:14:21Z",
                "status": "True",
                "type": "PodScheduled"
            }
        ],
        "containerStatuses": [
            {
                "containerID": "cri-o://6f25dbe62dbbb4071eed939d37b5981f50bc56b7ac61d93707b0607493f8d360",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode1-0",
                "ready": true,
                "restartCount": 0,
                "started": true,
                "state": {
                    "running": {
                        "startedAt": "2026-10-11T02:14:22Z"
                    }
                }
            }
        ],
        "hostIP": "192.168.77.12",
        "hostIPs": [
            {
                "ip": "192.168.77.12"
            }
        ],
        "initContainerStatuses": [
            {
                "containerID": "cri-o://21e5dc8fd970e47d760706429258bf58199d1c9724601de5fc4f801143a820bd",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode1-init1",
                "ready": true,
                "restartCount": 0,
                "started": false,
                "state": {
                    "terminated": {
                        "containerID": "cri-o://21e5dc8fd970e47d760706429258bf58199d1c9724601de5fc4f801143a820bd",
                        "exitCode": 0,
                        "finishedAt": "2026-10-11T02:14:22Z",
                        "reason": "Completed",
                        "startedAt": "2026-10-11T02:14:22Z"
                    }
                }
            }
        ],
        "phase": "Running",
        "podIP": "10.244.1.9",
        "podIPs": [
            {
                "ip": "10.244.1.9"
            }
        ],
        "qosClass": "Burstable",
        "startTime": "2026-10-11T02:14:21Z"
    }
}
Exit code: 0

UTC 2026-10-11T23:56:58.644682+00:00 $ kubectl exec -n rac racnode1-0 -- cmp /etc/oracle/olr.loc /u01/app/grid/.etcoraclebackup/oracle/olr.loc
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-11T23:56:58.787940+00:00 $ kubectl exec -n rac racnode1-0 -- cmp /etc/oracle/ocr.loc /u01/app/grid/.etcoraclebackup/oracle/ocr.loc
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0
SCENARIO S07: normal replacement of racnode1-0; old UID=0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4

UTC 2026-10-11T23:56:58.934215+00:00 $ kubectl -n rac delete pod racnode1-0 --grace-period=120 --wait=false
pod "racnode1-0" deleted
Exit code: 0
2026-10-11T23:56:59.134489+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:57:14.222462+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:57:29.317925+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:57:44.388790+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:57:59.470686+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:58:14.552445+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:58:29.637050+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:58:44.719321+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Running Ready=True deleting=True
2026-10-11T23:58:59.834582+00:00 racnode1-0 0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4 Failed Ready=False deleting=True
2026-10-11T23:59:14.930130+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-11T23:59:30.027144+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-11T23:59:45.123457+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:00:00.202830+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:00:15.291030+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:00:30.376206+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:00:45.466949+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:01:00.555760+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:01:15.635616+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:01:30.718005+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:01:45.799144+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:02:00.885089+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=False deleting=False
2026-10-12T00:02:15.954535+00:00 racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 Running Ready=True deleting=False

UTC 2026-10-12T00:02:15.954619+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          3m16s   10.244.1.11   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          12m     10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:02:16.013355+00:00 $ kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/crsctl check crs
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:02:16.209979+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

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

UTC 2026-10-12T00:02:16.605875+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:02:17.442051+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          3m17s   10.244.1.11   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          12m     10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:02:17.508728+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:02:17.868913+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-12T00:02:18.236822+00:00 $ kubectl -n rac get pod racnode1-0 -o json
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "annotations": {
            "database.oracle.com/rac-configmap-hash": "e846a808193d5b3cf7ab3f4f150cec01e551b515fddd5d3b5826364bc79acf66",
            "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"cbr0\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.244.1.11\"\n    ],\n    \"mac\": \"7a:ef:9a:c6:9c:4d\",\n    \"default\": true,\n    \"dns\": {},\n    \"gateway\": [\n        \"10.244.1.1\"\n    ]\n},{\n    \"name\": \"rac/macvlan-conf1\",\n    \"interface\": \"ens1\",\n    \"ips\": [\n        \"192.168.78.120\"\n    ],\n    \"mac\": \"f2:65:3e:37:20:4a\",\n    \"dns\": {}\n},{\n    \"name\": \"rac/macvlan-conf2\",\n    \"interface\": \"ens2\",\n    \"ips\": [\n        \"192.168.79.120\"\n    ],\n    \"mac\": \"2e:60:46:ac:c8:96\",\n    \"dns\": {}\n}]",
            "k8s.v1.cni.cncf.io/networks": "[{\"interface\":\"ens1\",\"ips\":[\"192.168.78.120/24\"],\"name\":\"macvlan-conf1\",\"namespace\":\"rac\"},{\"interface\":\"ens2\",\"ips\":[\"192.168.79.120/24\"],\"name\":\"macvlan-conf2\",\"namespace\":\"rac\"}]"
        },
        "creationTimestamp": "2026-10-11T23:59:00Z",
        "generateName": "racnode1-",
        "labels": {
            "app": "oracle-database-operator",
            "apps.kubernetes.io/pod-index": "0",
            "controller-revision-hash": "racnode1-6d89d8bc59",
            "database.oracle.com/component": "RAC",
            "database.oracle.com/managed-by": "racdatabase-controller",
            "database.oracle.com/name": "rac19c",
            "statefulset.kubernetes.io/pod-name": "racnode1-0"
        },
        "name": "racnode1-0",
        "namespace": "rac",
        "ownerReferences": [
            {
                "apiVersion": "apps/v1",
                "blockOwnerDeletion": true,
                "controller": true,
                "kind": "StatefulSet",
                "name": "racnode1",
                "uid": "d3987707-1668-494f-885f-864301da3cb4"
            }
        ],
        "resourceVersion": "390696",
        "uid": "590e8b8f-3a93-43d1-a8ea-3549e6b83201"
    },
    "spec": {
        "affinity": {
            "nodeAffinity": {
                "requiredDuringSchedulingIgnoredDuringExecution": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {
                                    "key": "raccluster",
                                    "operator": "In",
                                    "values": [
                                        "raccluster01"
                                    ]
                                },
                                {
                                    "key": "kubernetes.io/hostname",
                                    "operator": "In",
                                    "values": [
                                        "ocne-w1.lab.test"
                                    ]
                                }
                            ]
                        }
                    ]
                }
            }
        },
        "containers": [
            {
                "command": [
                    "/usr/sbin/init"
                ],
                "env": [
                    {
                        "name": "ORACLE_PDB_NAME",
                        "value": "LABPDB"
                    },
                    {
                        "name": "LOG_DIR",
                        "value": "/tmp/orod"
                    },
                    {
                        "name": "TOTAL_MEMORY",
                        "value": "16384"
                    }
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode1-0",
                "ports": [
                    {
                        "containerPort": 1521,
                        "name": "tcp-1521lv5bb",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 1522,
                        "name": "tcp-1522gtk9k",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 22,
                        "name": "tcp-22hct82",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 6200,
                        "name": "tcp-6200nbrd7",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 8080,
                        "name": "tcp-8080pmc4d",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 31522,
                        "name": "tcp-31522vggpw",
                        "protocol": "TCP"
                    },
                    {
                        "containerPort": 30200,
                        "name": "tcp-30200k6cr8",
                        "protocol": "TCP"
                    }
                ],
                "readinessProbe": {
                    "failureThreshold": 3,
                    "initialDelaySeconds": 180,
                    "periodSeconds": 5,
                    "successThreshold": 1,
                    "tcpSocket": {
                        "port": 31522
                    },
                    "timeoutSeconds": 1
                },
                "resources": {
                    "limits": {
                        "cpu": "4",
                        "memory": "16Gi"
                    },
                    "requests": {
                        "cpu": "4",
                        "memory": "16Gi"
                    }
                },
                "securityContext": {
                    "capabilities": {
                        "add": [
                            "NET_ADMIN",
                            "SYS_NICE",
                            "SYS_RESOURCE",
                            "AUDIT_WRITE",
                            "NET_RAW",
                            "AUDIT_CONTROL",
                            "SYS_CHROOT"
                        ]
                    },
                    "privileged": false
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeDevices": [
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm01",
                        "name": "asm-pvc-16e0716b-rac19c"
                    },
                    {
                        "devicePath": "/dev/disk/by-partlabel/ocne-rac-asm02",
                        "name": "asm-pvc-ee86c2c9-rac19c"
                    }
                ],
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode1-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode1-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode1-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode1-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode1-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode1-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode1-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-4b4rz",
                        "readOnly": true
                    }
                ]
            }
        ],
        "dnsPolicy": "ClusterFirst",
        "enableServiceLinks": true,
        "hostname": "racnode1-0",
        "initContainers": [
            {
                "command": [
                    "/bin/bash",
                    "-c",
                    "\n\t\tsysctl -w net.ipv4.conf.all.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.default.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens1.rp_filter=2 || true \u0026\u0026\n\t\tsysctl -w net.ipv4.conf.ens2.rp_filter=2 || true \u0026\u0026\n\n\t\tIP1=$(ip addr show ens1 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\t\tIP2=$(ip addr show ens2 | awk '/inet /{print $2}' | cut -d/ -f1) \u0026\u0026 \n\n\t\t# Write environment file (overwrite + append)\n\t\tif [ -n \"$IP1\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP1=$IP1\" \u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t\tif [ -n \"$IP2\" ]; then\n\t\t\techo \"CRS_PRIVATE_IP2=$IP2\" \u003e\u003e /etc/rac_env_vars_writable/envfile;\n\t\tfi;\n\n\t/bin/true"
                ],
                "image": "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d",
                "imagePullPolicy": "IfNotPresent",
                "name": "racnode1-init1",
                "resources": {},
                "securityContext": {
                    "privileged": true,
                    "runAsUser": 0
                },
                "terminationMessagePath": "/dev/termination-log",
                "terminationMessagePolicy": "File",
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/.ssh",
                        "name": "racnode1-ssh-secretmap-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/mnt/.dbsecrets",
                        "name": "racnode1-dbsecret-pwd-vol",
                        "readOnly": true
                    },
                    {
                        "mountPath": "/dev/shm",
                        "name": "racnode1-oradshm-vol"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars",
                        "name": "racnode1-oradata-envfile"
                    },
                    {
                        "mountPath": "/etc/rac_env_vars_writable",
                        "name": "racnode1-oradata-envfile-writable"
                    },
                    {
                        "mountPath": "/u01",
                        "name": "racnode1-oradata-sw-vol"
                    },
                    {
                        "mountPath": "/mnt/stage/software",
                        "name": "racnode1-oradata-swstage-vol"
                    },
                    {
                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
                        "name": "kube-api-access-4b4rz",
                        "readOnly": true
                    }
                ]
            }
        ],
        "nodeName": "ocne-w1.lab.test",
        "preemptionPolicy": "PreemptLowerPriority",
        "priority": 0,
        "restartPolicy": "Always",
        "schedulerName": "default-scheduler",
        "securityContext": {
            "sysctls": [
                {
                    "name": "kernel.shmall",
                    "value": "2097152"
                },
                {
                    "name": "kernel.shmmax",
                    "value": "8589934592"
                },
                {
                    "name": "kernel.shmmni",
                    "value": "4096"
                },
                {
                    "name": "kernel.sem",
                    "value": "250 32000 100 128"
                },
                {
                    "name": "net.ipv4.conf.all.rp_filter",
                    "value": "2"
                }
            ]
        },
        "serviceAccount": "default",
        "serviceAccountName": "default",
        "subdomain": "racnode",
        "terminationGracePeriodSeconds": 30,
        "tolerations": [
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/not-ready",
                "operator": "Exists",
                "tolerationSeconds": 300
            },
            {
                "effect": "NoExecute",
                "key": "node.kubernetes.io/unreachable",
                "operator": "Exists",
                "tolerationSeconds": 300
            }
        ],
        "volumes": [
            {
                "name": "racnode1-ssh-secretmap-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-ssh-key"
                }
            },
            {
                "emptyDir": {
                    "medium": "Memory"
                },
                "name": "racnode1-oradshm-vol"
            },
            {
                "name": "racnode1-dbsecret-pwd-vol",
                "secret": {
                    "defaultMode": 420,
                    "secretName": "rac-db-password"
                }
            },
            {
                "configMap": {
                    "defaultMode": 420,
                    "name": "racnode1rac19c-cmap"
                },
                "name": "racnode1-oradata-envfile"
            },
            {
                "hostPath": {
                    "path": "/scratch/rac/cluster01/racnode1",
                    "type": ""
                },
                "name": "racnode1-oradata-sw-vol"
            },
            {
                "hostPath": {
                    "path": "/scratch/software/stage/19c/19.32-gold",
                    "type": ""
                },
                "name": "racnode1-oradata-swstage-vol"
            },
            {
                "name": "asm-pvc-16e0716b-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-16e0716b-rac19c"
                }
            },
            {
                "name": "asm-pvc-ee86c2c9-rac19c",
                "persistentVolumeClaim": {
                    "claimName": "asm-pvc-ee86c2c9-rac19c"
                }
            },
            {
                "emptyDir": {},
                "name": "racnode1-oradata-envfile-writable"
            },
            {
                "name": "kube-api-access-4b4rz",
                "projected": {
                    "defaultMode": 420,
                    "sources": [
                        {
                            "serviceAccountToken": {
                                "expirationSeconds": 3607,
                                "path": "token"
                            }
                        },
                        {
                            "configMap": {
                                "items": [
                                    {
                                        "key": "ca.crt",
                                        "path": "ca.crt"
                                    }
                                ],
                                "name": "kube-root-ca.crt"
                            }
                        },
                        {
                            "downwardAPI": {
                                "items": [
                                    {
                                        "fieldRef": {
                                            "apiVersion": "v1",
                                            "fieldPath": "metadata.namespace"
                                        },
                                        "path": "namespace"
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        ]
    },
    "status": {
        "conditions": [
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T23:59:02Z",
                "status": "True",
                "type": "PodReadyToStartContainers"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T23:59:02Z",
                "status": "True",
                "type": "Initialized"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-12T00:02:05Z",
                "status": "True",
                "type": "Ready"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-12T00:02:05Z",
                "status": "True",
                "type": "ContainersReady"
            },
            {
                "lastProbeTime": null,
                "lastTransitionTime": "2026-10-11T23:59:00Z",
                "status": "True",
                "type": "PodScheduled"
            }
        ],
        "containerStatuses": [
            {
                "containerID": "cri-o://355c59bdbd922e68562df052c5996dc12820a9e8fa41a47e98b3ac484079e3d5",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode1-0",
                "ready": true,
                "restartCount": 0,
                "started": true,
                "state": {
                    "running": {
                        "startedAt": "2026-10-11T23:59:02Z"
                    }
                }
            }
        ],
        "hostIP": "192.168.77.12",
        "hostIPs": [
            {
                "ip": "192.168.77.12"
            }
        ],
        "initContainerStatuses": [
            {
                "containerID": "cri-o://5b643314fd15f553b79acbac0b3b8bc7e1a0a0cdc03b5dd4af5d7545d25a17ba",
                "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                "lastState": {},
                "name": "racnode1-init1",
                "ready": true,
                "restartCount": 0,
                "started": false,
                "state": {
                    "terminated": {
                        "containerID": "cri-o://5b643314fd15f553b79acbac0b3b8bc7e1a0a0cdc03b5dd4af5d7545d25a17ba",
                        "exitCode": 0,
                        "finishedAt": "2026-10-11T23:59:01Z",
                        "reason": "Completed",
                        "startedAt": "2026-10-11T23:59:01Z"
                    }
                }
            }
        ],
        "phase": "Running",
        "podIP": "10.244.1.11",
        "podIPs": [
            {
                "ip": "10.244.1.11"
            }
        ],
        "qosClass": "Burstable",
        "startTime": "2026-10-11T23:59:00Z"
    }
}
Exit code: 0
SCENARIO S07: PASS; new UID=590e8b8f-3a93-43d1-a8ea-3549e6b83201
Node1 replacement completed; assess alongside the assisted node2 recovery transcript.
```

</details>

## Exact startup error contexts, captured next morning

Evidence: `logs/ssh-ocne-cp-Capture-RAC-Restart-Incident-20261012-074614.txt`.

<details>
<summary>Complete command output</summary>

```text
=== Restart incident: racnode1-0 ===
Selected restart contexts; original line numbers retained
3333:
3334: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   executeprocess   :Received Command : su - grid -c "/u01/app/19c/grid/bin/oraversion -majorVersion"
3335: 10/11/2026 11:59:18 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : 19
3336:
3337: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   restoregifiles   :restore_gi_files invoked (Oracle major version: 19)
3338: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   restoregifiles   :Found /etc/oracle backup at /u01/app/grid/.etcoraclebackup, restoring
3339: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   executeprocess   :Received Command : cp -rp /u01/app/grid/.etcoraclebackup/oracle /etc/
3340: 10/11/2026 11:59:18 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : no Output
3341: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   restoregifiles   :CRS_GPC not set: updating OS files using rootcrs.sh
3342: 10/11/2026 11:59:18 PM     INFO:   oracommon   -   executeprocess   :Received Command : /u01/app/19c/grid/crs/install/rootcrs.sh -updateosfiles
3343: 10/11/2026 11:59:37 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : Using configuration parameter file: /u01/app/19c/grid/crs/install/crsconfig_params
3344: The log of current session can be found at:
3345:   /u01/app/grid/crsdata/racnode1-0/crsconfig/crsupdate_osfiles_racnode1-0_2026-10-11_11-59-19PM.log
3346: Redirecting to /bin/systemctl restart rsyslog.service
3347: 2026/10/11 23:59:20 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
3348:
3349: 10/11/2026 11:59:37 PM     INFO:   oracommon   -   restoregifiles   :Starting Oracle Clusterware (CRS)
3350: 10/11/2026 11:59:37 PM     INFO:   oracommon   -   executeprocess   :Received Command : /u01/app/19c/grid/bin/crsctl start crs
3351: 10/11/2026 11:59:42 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : CRS-4123: Oracle High Availability Services has been started.
3352:
3353: 10/11/2026 11:59:42 PM     INFO:   oracommon   -   restoregifiles   :GI restore completed and Oracle stack started successfully
3354: 10/11/2026 11:59:42 PM     INFO:   oracommon   -   executeprocess   :Received Command : su - grid  -c "sudo /u01/app/oraInventory/orainstRoot.sh"
3355: 10/11/2026 11:59:42 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : Changing permissions of /u01/app/oraInventory.
3356: Adding read,write permissions for group.
3357: Removing read,write,execute permissions for world.
3358:
3359: Changing groupname of /u01/app/oraInventory to oinstall.
3360: The execution of the script is complete.
3361:
3362: 10/11/2026 11:59:42 PM     INFO:   oracommon   -   executeprocess   :Received Command : /u01/app/19c/grid/bin/crsctl start crs
3363: 10/11/2026 11:59:42 PM  WARNING:   oracommon   -     checkoserr     :OS command returned code : 1, returned error : no returned error and returned output : CRS-4640: Oracle High Availability Services is already active
3364: CRS-4000: Command Start failed, or completed with errors.
3365:
3366: 10/11/2026 11:59:42 PM  WARNING:   oracommon   -     checkoserr     :OS command  failed. Flag is set to ignore this error!
3367: 10/11/2026 11:59:42 PM     INFO:  orasetupenv  -     setbanner      :
3368:           =====================================
3369:           Grid is not installed on this machine
3370:           =====================================
3371:
3372: 10/11/2026 11:59:42 PM     INFO:  orasetupenv  -finalizeorasetupenv :Total time for orasetupenv setup() = [ 39.453 ] seconds
3373: 10/11/2026 11:59:42 PM     INFO:   oracommon   -     checkfile      :Inside check_file()
3374: 10/11/2026 11:59:42 PM     INFO:   oracommon   - processclustervars :Inside process_cluster_vars()
3375: 10/11/2026 11:59:42 PM     INFO:   oracommon   - processclustervars :Cluster Node Desc: pubhost:racnode1-0,viphost:racnode1-0-vip
3592: 10/11/2026 11:59:55 PM     INFO:   oracommon   -    setpassword     :<redacted> set to HIDDEN_STRING generated using encrypted password file
3593: 10/11/2026 11:59:55 PM     INFO:   oracommon   -   executeprocess   :Received Command : su - grid -c "export CV_ASSUME_DISTID=OL8; /u01/app/19c/grid/gridSetup.sh -waitforcompletion  -noCopy  -silent  -responseFile /tmp/grid.rsp oracle.install.crs.config.netmaskList=eth0:255.255.0.0,ens1:255.255.255.0,ens2:255.255.255.0 oracle.install.asm.SYSASMPassword=<redacted> oracle.install.asm.monitorPassword=<redacted>    "
3594: 10/11/2026 11:59:58 PM  WARNING:   oracommon   -     checkoserr     :OS command returned code : 254, returned error : no returned error and returned output : Launching Oracle Grid Infrastructure Setup Wizard...
3595:
3596: [FATAL] [INS-40401] Oracle Grid Infrastructure is already configured on the system.
3597:    CAUSE: Only one instance of Oracle Grid Infrastructure software can be configured on a system.
3598:    ACTION: One of the following actions may be considered.
3599:
3600: 1. Choose Upgrade option to upgrade Oracle Grid Infrastructure.
3601:
3602:  2. It is possible that previous configuration of Oracle Grid Infrastructure was not cleaned properly. Refer to documentation on how to deinstall the product. After performing the deinstall, Oracle Grid Infarstructure can be installed and configured.
3603:
3604: 10/11/2026 11:59:58 PM  WARNING:   oracommon   -     checkoserr     :OS command  failed. Flag is set to ignore this error!
3605: 10/11/2026 11:59:58 PM    ERROR:   oragiprov   -validateinstallmarkers:Grid software install failed. Exiting...
3606: 10/11/2026 11:59:58 PM     INFO:   oracommon   -     checkfile      :Inside check_file()
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)

exit code 0
=== Restart incident: racnode2-0 ===
Selected restart contexts; original line numbers retained
3309:
3310: 10/11/2026 11:51:04 PM     INFO:   oracommon   -   executeprocess   :Received Command : su - grid -c "/u01/app/19c/grid/bin/oraversion -majorVersion"
3311: 10/11/2026 11:51:04 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : 19
3312:
3313: 10/11/2026 11:51:04 PM     INFO:   oracommon   -   restoregifiles   :restore_gi_files invoked (Oracle major version: 19)
3314: 10/11/2026 11:51:04 PM     INFO:   oracommon   -   restoregifiles   :Found /etc/oracle backup at /u01/app/grid/.etcoraclebackup, restoring
3315: 10/11/2026 11:51:04 PM     INFO:   oracommon   -   executeprocess   :Received Command : cp -rp /u01/app/grid/.etcoraclebackup/oracle /etc/
3316: 10/11/2026 11:51:04 PM  WARNING:   oracommon   -     checkoserr     :OS command returned code : 1, returned error : cp: cannot access '/u01/app/grid/.etcoraclebackup/oracle': Permission denied
3317:  and returned output : no retruned output
3318: 10/11/2026 11:51:04 PM  WARNING:   oracommon   -     checkoserr     :OS command  failed. Flag is set to ignore this error!
3319: 10/11/2026 11:51:04 PM    ERROR:   oracommon   -   restoregifiles   :Failed to restore /etc/oracle from backup
3320: 10/11/2026 11:51:04 PM     INFO:  orasetupenv  -     setbanner      :
3321:           =====================================
3322:           Grid is not installed on this machine
3323:           =====================================
3324:
3325: 10/11/2026 11:51:04 PM     INFO:  orasetupenv  -finalizeorasetupenv :Total time for orasetupenv setup() = [ 66.811 ] seconds
3326: 10/11/2026 11:51:04 PM     INFO:   oracommon   -     checkfile      :Inside check_file()
3327: 10/11/2026 11:51:04 PM     INFO:  orasetupenv  -waitfororasetupenvcompletion:Not INSTALL_NODE (racnode2-0), skipping wait_for_orasetupenv_completion
3328: 10/11/2026 11:51:04 PM     INFO:   oracommon   -   executeprocess   :Received Command : su - grid -c "/u01/app/19c/grid/bin/oraversion -majorVersion"
3329: 10/11/2026 11:51:04 PM     INFO:   oracommon   -     checkoserr     :OS command returned code : 0 and returned output : 19
3330:
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)

exit code 0
```

</details>

## Final CRS ASM patch SQL and memory acceptance

Evidence: `logs/ssh-ocne-cp-Verify-RAC-Database-20261011-200344.txt`.

<details>
<summary>Complete command output</summary>

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
racnode1-0  1
racnode2-0  2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    89608                0           89608              0             Y  DATA/
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

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


NAME      OPEN_MODE        DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 PDB$SEED                                                             READ ONLY
     1 LABPDB                                                               READ WRITE
     2 PDB$SEED                                                             READ ONLY
     2 LABPDB                                                               READ WRITE


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


    CON_ID   PATCH_ID ACTION          STATUS            DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
     1   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     1   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)
     3   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     3   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
racnode1-0  1
racnode2-0  2
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
State    Type    Rebal  Sector  Logical_Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512             512   4096  4194304    102392    89608                0           89608              0             Y  DATA/
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

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


NAME      OPEN_MODE        DATABASE_ROLE
--------- -------------------- ----------------
RACCDB    READ WRITE           PRIMARY


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 PDB$SEED                                                             READ ONLY
     1 LABPDB                                                               READ WRITE
     2 PDB$SEED                                                             READ ONLY
     2 LABPDB                                                               READ WRITE


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


    CON_ID   PATCH_ID ACTION          STATUS            DESCRIPTION
---------- ---------- --------------- ------------------------- ----------------------------------------------------------------------------------------------------
     1   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     1   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)
     3   39222882 APPLY       SUCCESS           OJVM RELEASE UPDATE: 19.32.0.0.260721 (39222882)
     3   39472050 APPLY       SUCCESS           Database Release Update : 19.32.0.0.260721 (39472050)


no rows selected


PL/SQL procedure successfully completed.

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
      1        ONLINE  ONLINE       racnode2-0               STABLE
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
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
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

</details>

## Interpretation of node1 result

Node1 used its prepared, relabeled backup to restore GI automatically. Its startup code then issued `crsctl start crs` a second time. CRS-4640/CRS-4000 (already active) was misclassified as GI not installed, and a redundant installer attempt failed safely with INS-40401. Existing GI/ASM/database continued online; no deinstall/reinstallation was performed to clear this error. SQL and network acceptance passed at00:02 UTC12October (20:02 EDT11October). This is database recovery with a remaining image startup defect, not a clean startup-script success. Correct the duplicate-start handling in a future image build and retest independently before claiming unattended recovery for both nodes.

The captured root cause for node2 was the copied old MCS label, not absence of a restore function: the image attempted the copy and got Permission denied. Worker-side restorecon plus the explicit assisted recovery succeeded. A repeat node2 replacement after relabel was not injected.

Output presentation: tabs are expanded and trailing padding is removed; raw local logs remain unchanged.
