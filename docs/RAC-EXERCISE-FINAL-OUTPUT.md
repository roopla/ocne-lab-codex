# RAC operator restart and final health: full output

The Database Operator deployment was restarted at00:03 UTC12October2026 (20:03 EDT11October). Its replacement became ready; both RAC pod UIDs stayed unchanged and both network SQL paths passed before/after. This tests controller replacement, not a prolonged API/webhook outage or transaction replay.

## Operator restart exercise

```text

UTC 2026-10-12T00:03:26.230609+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

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

UTC 2026-10-12T00:03:26.491043+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:27.329481+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          4m27s   10.244.1.11   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          13m     10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:03:27.396072+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:27.659464+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:27.996188+00:00 $ kubectl -n rac get pods -o json
{
    "apiVersion": "v1",
    "items": [
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
        },
        {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "annotations": {
                    "database.oracle.com/rac-configmap-hash": "bfd74fa7cef62fb8f9af88a0c1928697ed164fb54a2d14584bf2eb1e64c36597",
                    "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"cbr0\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.244.2.10\"\n    ],\n    \"mac\": \"5e:3c:df:2c:ba:e3\",\n    \"default\": true,\n    \"dns\": {},\n    \"gateway\": [\n        \"10.244.2.1\"\n    ]\n},{\n    \"name\": \"rac/macvlan-conf1\",\n    \"interface\": \"ens1\",\n    \"ips\": [\n        \"192.168.78.121\"\n    ],\n    \"mac\": \"26:5a:55:6f:21:84\",\n    \"dns\": {}\n},{\n    \"name\": \"rac/macvlan-conf2\",\n    \"interface\": \"ens2\",\n    \"ips\": [\n        \"192.168.79.121\"\n    ],\n    \"mac\": \"76:00:cd:21:bd:ef\",\n    \"dns\": {}\n}]",
                    "k8s.v1.cni.cncf.io/networks": "[{\"interface\":\"ens1\",\"ips\":[\"192.168.78.121/24\"],\"name\":\"macvlan-conf1\",\"namespace\":\"rac\"},{\"interface\":\"ens2\",\"ips\":[\"192.168.79.121/24\"],\"name\":\"macvlan-conf2\",\"namespace\":\"rac\"}]"
                },
                "creationTimestamp": "2026-10-11T23:49:55Z",
                "generateName": "racnode2-",
                "labels": {
                    "app": "oracle-database-operator",
                    "apps.kubernetes.io/pod-index": "0",
                    "controller-revision-hash": "racnode2-6c99798bfb",
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
                "resourceVersion": "389646",
                "uid": "e5fb5f48-cfcc-4476-97d9-07338262095d"
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
                                "name": "kube-api-access-4jv72",
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
                                "name": "kube-api-access-4jv72",
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
                        "name": "kube-api-access-4jv72",
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
                        "lastTransitionTime": "2026-10-11T23:49:57Z",
                        "status": "True",
                        "type": "PodReadyToStartContainers"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:49:57Z",
                        "status": "True",
                        "type": "Initialized"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:54:50Z",
                        "status": "True",
                        "type": "Ready"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:54:50Z",
                        "status": "True",
                        "type": "ContainersReady"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:49:55Z",
                        "status": "True",
                        "type": "PodScheduled"
                    }
                ],
                "containerStatuses": [
                    {
                        "containerID": "cri-o://d178a4ddf87c458a9c4297b4eff140081503d0908e8a38f42069c1f5842b2308",
                        "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                        "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                        "lastState": {},
                        "name": "racnode2-0",
                        "ready": true,
                        "restartCount": 0,
                        "started": true,
                        "state": {
                            "running": {
                                "startedAt": "2026-10-11T23:49:57Z"
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
                        "containerID": "cri-o://e1a6d490352855e132ec0f96c9be3d633c8994cd9d6b4e653d5e524944f9a05e",
                        "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                        "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                        "lastState": {},
                        "name": "racnode2-init1",
                        "ready": true,
                        "restartCount": 0,
                        "started": false,
                        "state": {
                            "terminated": {
                                "containerID": "cri-o://e1a6d490352855e132ec0f96c9be3d633c8994cd9d6b4e653d5e524944f9a05e",
                                "exitCode": 0,
                                "finishedAt": "2026-10-11T23:49:56Z",
                                "reason": "Completed",
                                "startedAt": "2026-10-11T23:49:56Z"
                            }
                        }
                    }
                ],
                "phase": "Running",
                "podIP": "10.244.2.10",
                "podIPs": [
                    {
                        "ip": "10.244.2.10"
                    }
                ],
                "qosClass": "Burstable",
                "startTime": "2026-10-11T23:49:55Z"
            }
        }
    ],
    "kind": "List",
    "metadata": {
        "resourceVersion": ""
    }
}
Exit code: 0
SCENARIO S21: restart Database Operator deployment only

UTC 2026-10-12T00:03:28.059874+00:00 $ kubectl -n oracle-database-operator-system get pods -o wide
NAME                                                          READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
oracle-database-operator-controller-manager-7c5c7c7f4-5k4kv   1/1     Running   1          35h   10.244.1.2   ocne-w1.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:03:28.123250+00:00 $ kubectl -n oracle-database-operator-system rollout restart deployment/oracle-database-operator-controller-manager
deployment.apps/oracle-database-operator-controller-manager restarted
Exit code: 0

UTC 2026-10-12T00:03:28.189479+00:00 $ kubectl -n oracle-database-operator-system rollout status deployment/oracle-database-operator-controller-manager --timeout=120s
Waiting for deployment "oracle-database-operator-controller-manager" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "oracle-database-operator-controller-manager" rollout to finish: 1 old replicas are pending termination...
deployment "oracle-database-operator-controller-manager" successfully rolled out
Exit code: 0

UTC 2026-10-12T00:03:30.237216+00:00 $ kubectl -n oracle-database-operator-system get pods -o wide
NAME                                                           READY   STATUS        RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
oracle-database-operator-controller-manager-6ff745fdbb-98hw4   1/1     Running       0          2s    10.244.1.12   ocne-w1.lab.test   <none>           <none>
oracle-database-operator-controller-manager-7c5c7c7f4-5k4kv    1/1     Terminating   1          35h   10.244.1.2    ocne-w1.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:03:30.301985+00:00 $ kubectl -n rac get pods -o json
{
    "apiVersion": "v1",
    "items": [
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
        },
        {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "annotations": {
                    "database.oracle.com/rac-configmap-hash": "bfd74fa7cef62fb8f9af88a0c1928697ed164fb54a2d14584bf2eb1e64c36597",
                    "k8s.v1.cni.cncf.io/network-status": "[{\n    \"name\": \"cbr0\",\n    \"interface\": \"eth0\",\n    \"ips\": [\n        \"10.244.2.10\"\n    ],\n    \"mac\": \"5e:3c:df:2c:ba:e3\",\n    \"default\": true,\n    \"dns\": {},\n    \"gateway\": [\n        \"10.244.2.1\"\n    ]\n},{\n    \"name\": \"rac/macvlan-conf1\",\n    \"interface\": \"ens1\",\n    \"ips\": [\n        \"192.168.78.121\"\n    ],\n    \"mac\": \"26:5a:55:6f:21:84\",\n    \"dns\": {}\n},{\n    \"name\": \"rac/macvlan-conf2\",\n    \"interface\": \"ens2\",\n    \"ips\": [\n        \"192.168.79.121\"\n    ],\n    \"mac\": \"76:00:cd:21:bd:ef\",\n    \"dns\": {}\n}]",
                    "k8s.v1.cni.cncf.io/networks": "[{\"interface\":\"ens1\",\"ips\":[\"192.168.78.121/24\"],\"name\":\"macvlan-conf1\",\"namespace\":\"rac\"},{\"interface\":\"ens2\",\"ips\":[\"192.168.79.121/24\"],\"name\":\"macvlan-conf2\",\"namespace\":\"rac\"}]"
                },
                "creationTimestamp": "2026-10-11T23:49:55Z",
                "generateName": "racnode2-",
                "labels": {
                    "app": "oracle-database-operator",
                    "apps.kubernetes.io/pod-index": "0",
                    "controller-revision-hash": "racnode2-6c99798bfb",
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
                "resourceVersion": "389646",
                "uid": "e5fb5f48-cfcc-4476-97d9-07338262095d"
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
                                "name": "kube-api-access-4jv72",
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
                                "name": "kube-api-access-4jv72",
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
                        "name": "kube-api-access-4jv72",
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
                        "lastTransitionTime": "2026-10-11T23:49:57Z",
                        "status": "True",
                        "type": "PodReadyToStartContainers"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:49:57Z",
                        "status": "True",
                        "type": "Initialized"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:54:50Z",
                        "status": "True",
                        "type": "Ready"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:54:50Z",
                        "status": "True",
                        "type": "ContainersReady"
                    },
                    {
                        "lastProbeTime": null,
                        "lastTransitionTime": "2026-10-11T23:49:55Z",
                        "status": "True",
                        "type": "PodScheduled"
                    }
                ],
                "containerStatuses": [
                    {
                        "containerID": "cri-o://d178a4ddf87c458a9c4297b4eff140081503d0908e8a38f42069c1f5842b2308",
                        "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                        "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                        "lastState": {},
                        "name": "racnode2-0",
                        "ready": true,
                        "restartCount": 0,
                        "started": true,
                        "state": {
                            "running": {
                                "startedAt": "2026-10-11T23:49:57Z"
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
                        "containerID": "cri-o://e1a6d490352855e132ec0f96c9be3d633c8994cd9d6b4e653d5e524944f9a05e",
                        "image": "docker.io/roopla/oracle-rac:19.3.0-slim",
                        "imageID": "d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52",
                        "lastState": {},
                        "name": "racnode2-init1",
                        "ready": true,
                        "restartCount": 0,
                        "started": false,
                        "state": {
                            "terminated": {
                                "containerID": "cri-o://e1a6d490352855e132ec0f96c9be3d633c8994cd9d6b4e653d5e524944f9a05e",
                                "exitCode": 0,
                                "finishedAt": "2026-10-11T23:49:56Z",
                                "reason": "Completed",
                                "startedAt": "2026-10-11T23:49:56Z"
                            }
                        }
                    }
                ],
                "phase": "Running",
                "podIP": "10.244.2.10",
                "podIPs": [
                    {
                        "ip": "10.244.2.10"
                    }
                ],
                "qosClass": "Burstable",
                "startTime": "2026-10-11T23:49:55Z"
            }
        }
    ],
    "kind": "List",
    "metadata": {
        "resourceVersion": ""
    }
}
Exit code: 0

UTC 2026-10-12T00:03:30.367925+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '"'"'/ as sysdba'"'"''

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

UTC 2026-10-12T00:03:30.617074+00:00 $ kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
Service labpdb_app is running on instance(s) RACCDB1,RACCDB2
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:31.456611+00:00 $ kubectl -n rac get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          4m31s   10.244.1.11   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          13m     10.244.2.10   ocne-w2.lab.test   <none>           <none>
Exit code: 0

UTC 2026-10-12T00:03:31.518285+00:00 $ kubectl exec -i -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB1


PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:31.782647+00:00 $ kubectl exec -i -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'

PDB          INSTANCE_NAME
-------------------- --------------------
LABPDB           RACCDB2


PL/SQL procedure successfully completed.

Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

UTC 2026-10-12T00:03:32.043568+00:00 $ kubectl get nodes -o wide
NAME               STATUS   ROLES           AGE   VERSION          INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                  KERNEL-VERSION                     CONTAINER-RUNTIME
ocne-cp.lab.test   Ready    control-plane   9d    v1.29.14+2.el9   192.168.77.11   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w1.lab.test   Ready    <none>          9d    v1.29.14+2.el9   192.168.77.12   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w2.lab.test   Ready    <none>          9d    v1.29.14+2.el9   192.168.77.13   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
Exit code: 0

UTC 2026-10-12T00:03:32.098106+00:00 $ kubectl -n rac get pvc
NAME                      STATUS   VOLUME                   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
asm-pvc-16e0716b-rac19c   Bound    asm-pv-16e0716b-rac19c   49Gi       RWX                           <unset>                 21h
asm-pvc-ee86c2c9-rac19c   Bound    asm-pv-ee86c2c9-rac19c   49Gi       RWX                           <unset>                 21h
Exit code: 0

UTC 2026-10-12T00:03:32.153820+00:00 $ kubectl get pv
NAME                     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
asm-pv-16e0716b-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-16e0716b-rac19c                  <unset>                          21h
asm-pv-ee86c2c9-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-ee86c2c9-rac19c                  <unset>                          21h
Exit code: 0
FINAL POD racnode1-0 590e8b8f-3a93-43d1-a8ea-3549e6b83201 10.244.1.11 ocne-w1.lab.test {"limits": {"cpu": "4", "memory": "16Gi"}, "requests": {"cpu": "4", "memory": "16Gi"}}
FINAL POD racnode2-0 e5fb5f48-cfcc-4476-97d9-07338262095d 10.244.2.10 ocne-w2.lab.test {"limits": {"cpu": "4", "memory": "16Gi"}, "requests": {"cpu": "4", "memory": "16Gi"}}

UTC 2026-10-12T00:03:32.211578+00:00 $ kubectl -n rac get events --sort-by=.metadata.creationTimestamp
LAST SEEN   TYPE      REASON                  OBJECT                           MESSAGE
15m         Normal    Killing                 pod/racnode2-0                   Stopping container racnode2-0
13m         Normal    Scheduled               pod/racnode2-0                   Successfully assigned rac/racnode2-0 to ocne-w2.lab.test
13m         Normal    SuccessfulMountVolume   pod/racnode2-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-ee86c2c9-rac19c" volumeMapPath "/var/lib/kubelet/pods/e5fb5f48-cfcc-4476-97d9-07338262095d/volumeDevices/kubernetes.io~local-volume"
13m         Normal    SuccessfulMountVolume   pod/racnode2-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-ee86c2c9-rac19c" globalMapPath "/var/lib/kubelet/plugins/kubernetes.io~local-volume/volumeDevices/asm-pv-ee86c2c9-rac19c"
13m         Normal    SuccessfulMountVolume   pod/racnode2-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-16e0716b-rac19c" volumeMapPath "/var/lib/kubelet/pods/e5fb5f48-cfcc-4476-97d9-07338262095d/volumeDevices/kubernetes.io~local-volume"
13m         Normal    SuccessfulMountVolume   pod/racnode2-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-16e0716b-rac19c" globalMapPath "/var/lib/kubelet/plugins/kubernetes.io~local-volume/volumeDevices/asm-pv-16e0716b-rac19c"
13m         Normal    SuccessfulCreate        statefulset/racnode2             create Pod racnode2-0 in StatefulSet racnode2 successful
13m         Normal    AddedInterface          pod/racnode2-0                   Add ens1 [192.168.78.121/24] from rac/macvlan-conf1
13m         Normal    Pulled                  pod/racnode2-0                   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
13m         Normal    AddedInterface          pod/racnode2-0                   Add eth0 [10.244.2.10/24] from cbr0
13m         Normal    Started                 pod/racnode2-0                   Started container racnode2-init1
13m         Normal    Created                 pod/racnode2-0                   Created container: racnode2-init1
13m         Normal    AddedInterface          pod/racnode2-0                   Add ens2 [192.168.79.121/24] from rac/macvlan-conf2
13m         Normal    Created                 pod/racnode2-0                   Created container: racnode2-0
13m         Normal    Started                 pod/racnode2-0                   Started container racnode2-0
13m         Normal    Pulled                  pod/racnode2-0                   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
9m27s       Warning   Unhealthy               pod/racnode2-0                   Readiness probe failed: dial tcp 10.244.2.10:31522: connect: connection refused
6m33s       Normal    Killing                 pod/racnode1-0                   Stopping container racnode1-0
4m33s       Normal    SuccessfulCreate        daemonset/disk-check-daemonset   Created pod: disk-check-daemonset-8hkls
4m33s       Normal    SuccessfulCreate        daemonset/disk-check-daemonset   Created pod: disk-check-daemonset-n92kk
4m32s       Normal    Scheduled               pod/disk-check-daemonset-n92kk   Successfully assigned rac/disk-check-daemonset-n92kk to ocne-w1.lab.test
4m32s       Normal    Scheduled               pod/disk-check-daemonset-8hkls   Successfully assigned rac/disk-check-daemonset-8hkls to ocne-w2.lab.test
4m32s       Normal    Created                 pod/disk-check-daemonset-n92kk   Created container: disk-check
4m32s       Normal    SuccessfulMountVolume   pod/racnode1-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-16e0716b-rac19c" volumeMapPath "/var/lib/kubelet/pods/590e8b8f-3a93-43d1-a8ea-3549e6b83201/volumeDevices/kubernetes.io~local-volume"
4m32s       Normal    SuccessfulMountVolume   pod/racnode1-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-16e0716b-rac19c" globalMapPath "/var/lib/kubelet/plugins/kubernetes.io~local-volume/volumeDevices/asm-pv-16e0716b-rac19c"
4m32s       Normal    SuccessfulMountVolume   pod/racnode1-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-ee86c2c9-rac19c" volumeMapPath "/var/lib/kubelet/pods/590e8b8f-3a93-43d1-a8ea-3549e6b83201/volumeDevices/kubernetes.io~local-volume"
4m32s       Normal    SuccessfulMountVolume   pod/racnode1-0                   MapVolume.MapPodDevice succeeded for volume "asm-pv-ee86c2c9-rac19c" globalMapPath "/var/lib/kubelet/plugins/kubernetes.io~local-volume/volumeDevices/asm-pv-ee86c2c9-rac19c"
4m31s       Normal    Scheduled               pod/racnode1-0                   Successfully assigned rac/racnode1-0 to ocne-w1.lab.test
4m32s       Normal    Started                 pod/disk-check-daemonset-n92kk   Started container disk-check
4m32s       Normal    SuccessfulCreate        statefulset/racnode1             create Pod racnode1-0 in StatefulSet racnode1 successful
4m32s       Normal    Pulled                  pod/disk-check-daemonset-n92kk   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
4m32s       Normal    AddedInterface          pod/disk-check-daemonset-n92kk   Add eth0 [10.244.1.10/24] from cbr0
4m32s       Normal    Started                 pod/disk-check-daemonset-8hkls   Started container disk-check
4m32s       Normal    Created                 pod/disk-check-daemonset-8hkls   Created container: disk-check
4m32s       Normal    Pulled                  pod/disk-check-daemonset-8hkls   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
4m32s       Normal    AddedInterface          pod/disk-check-daemonset-8hkls   Add eth0 [10.244.2.11/24] from cbr0
4m31s       Normal    AddedInterface          pod/racnode1-0                   Add ens2 [192.168.79.120/24] from rac/macvlan-conf2
4m31s       Normal    Started                 pod/racnode1-0                   Started container racnode1-init1
4m31s       Normal    Created                 pod/racnode1-0                   Created container: racnode1-init1
4m31s       Normal    Pulled                  pod/racnode1-0                   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
4m31s       Normal    AddedInterface          pod/racnode1-0                   Add ens1 [192.168.78.120/24] from rac/macvlan-conf1
4m31s       Normal    AddedInterface          pod/racnode1-0                   Add eth0 [10.244.1.11/24] from cbr0
4m30s       Normal    Started                 pod/racnode1-0                   Started container racnode1-0
4m30s       Normal    Created                 pod/racnode1-0                   Created container: racnode1-0
4m30s       Normal    Pulled                  pod/racnode1-0                   Container image "docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d" already present on machine
4m23s       Normal    Killing                 pod/disk-check-daemonset-n92kk   Stopping container disk-check
4m23s       Normal    Killing                 pod/disk-check-daemonset-8hkls   Stopping container disk-check
Exit code: 0
S21 passed: controller replaced, RAC pod UIDs unchanged, both SQL paths healthy.
```

## Next-morning health and connections

Captured12October2026 at11:44UTC /07:44EDT. Both pods remained Running with restartCount0, both instances OPEN/ACTIVE, LABPDB READ WRITE, SGA3GiB/PGA2GiB and USE_LARGE_PAGES=FALSE; both NodePort SQL paths passed. CR status had refreshed to OPEN/PRIMARY/19.32 after its transient Pending fields; the legacy ORCLPDB connection summary remains stale.

```text
Captured UTC: 2026-10-12T11:44:55.216804+00:00

$ kubectl get nodes -o wide
NAME               STATUS   ROLES           AGE   VERSION          INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                  KERNEL-VERSION                     CONTAINER-RUNTIME
ocne-cp.lab.test   Ready    control-plane   10d   v1.29.14+2.el9   192.168.77.11   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w1.lab.test   Ready    <none>          10d   v1.29.14+2.el9   192.168.77.12   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w2.lab.test   Ready    <none>          10d   v1.29.14+2.el9   192.168.77.13   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1

$ kubectl -n rac get racdatabases,pods,statefulsets,services,pvc -o wide
NAME                                     DBNAME   DBSTATE   ROLE      VERSION       PDB CONNECT STR             STATE
racdatabase.database.oracle.com/rac19c   RACCDB   OPEN      PRIMARY   19.32.0.0.0   racnode-scan:1521/ORCLPDB   AVAILABLE

NAME             READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
pod/racnode1-0   1/1     Running   0          11h   10.244.1.11   ocne-w1.lab.test   <none>           <none>
pod/racnode2-0   1/1     Running   0          11h   10.244.2.10   ocne-w2.lab.test   <none>           <none>

NAME                        READY   AGE   CONTAINERS   IMAGES
statefulset.apps/racnode1   1/1     33h   racnode1-0   docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
statefulset.apps/racnode2   1/1     33h   racnode2-0   docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d

NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE   SELECTOR
service/racnode-scan        ClusterIP   None             <none>        <none>            33h   app=oracle-database-operator,database.oracle.com/component=RAC,database.oracle.com/managed-by=racdatabase-controller,database.oracle.com/name=rac19c
service/racnode-scan-lsnr   NodePort    10.104.49.126    <none>        1521:31521/TCP    33h   statefulset.kubernetes.io/pod-name=racnode1-0
service/racnode1-0          ClusterIP   None             <none>        <none>            33h   statefulset.kubernetes.io/pod-name=racnode1-0
service/racnode1-0-lsnr     NodePort    10.96.75.114     <none>        31522:31522/TCP   33h   statefulset.kubernetes.io/pod-name=racnode1-0
service/racnode1-0-ons      NodePort    10.96.6.122      <none>        6200:30200/TCP    33h   statefulset.kubernetes.io/pod-name=racnode1-0
service/racnode1-0-vip      ClusterIP   None             <none>        <none>            33h   statefulset.kubernetes.io/pod-name=racnode1-0
service/racnode2-0          ClusterIP   None             <none>        <none>            33h   statefulset.kubernetes.io/pod-name=racnode2-0
service/racnode2-0-lsnr     NodePort    10.102.225.198   <none>        31523:31523/TCP   33h   statefulset.kubernetes.io/pod-name=racnode2-0
service/racnode2-0-ons      NodePort    10.108.138.93    <none>        6200:30201/TCP    33h   statefulset.kubernetes.io/pod-name=racnode2-0
service/racnode2-0-vip      ClusterIP   None             <none>        <none>            33h   statefulset.kubernetes.io/pod-name=racnode2-0

NAME                                            STATUS   VOLUME                   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/asm-pvc-16e0716b-rac19c   Bound    asm-pv-16e0716b-rac19c   49Gi       RWX                           <unset>                 33h   Block
persistentvolumeclaim/asm-pvc-ee86c2c9-rac19c   Bound    asm-pv-ee86c2c9-rac19c   49Gi       RWX                           <unset>                 33h   Block

$ kubectl get pv
NAME                     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
asm-pv-16e0716b-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-16e0716b-rac19c                  <unset>                          33h
asm-pv-ee86c2c9-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-ee86c2c9-rac19c                  <unset>                          33h

$ kubectl -n oracle-database-operator-system get pods,certificates
NAME                                                               READY   STATUS    RESTARTS   AGE
pod/oracle-database-operator-controller-manager-6ff745fdbb-98hw4   1/1     Running   0          11h

NAME                                                                 READY   SECRET                AGE
certificate.cert-manager.io/oracle-database-operator-metrics-certs   True    metrics-server-cert   47h
certificate.cert-manager.io/oracle-database-operator-serving-cert    True    webhook-server-cert   47h

$ kubectl -n cert-manager get deployments
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
cert-manager              1/1     1            1           47h
cert-manager-cainjector   1/1     1            1           47h
cert-manager-webhook      1/1     1            1           47h

$ kubectl -n kube-system get daemonset kube-multus-ds
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-multus-ds   3         3         3       3            3           <none>          2d9h

$ kubectl -n rac get statefulsets -o custom-columns=NAME:.metadata.name,STRATEGY:.spec.updateStrategy.type,REPLICAS:.spec.replicas
NAME       STRATEGY   REPLICAS
racnode1   OnDelete   1
racnode2   OnDelete   1
Control-plane TCP to 192.168.77.12:31522: PASS
Network SQL through 192.168.77.12:31522/labpdb_app (client in racnode1-0):

PDB
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSTANCE_NAME
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
LABPDB
RACCDB1



PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Control-plane TCP to 192.168.77.13:31523: PASS
Network SQL through 192.168.77.13:31523/labpdb_app (client in racnode1-0):

PDB
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSTANCE_NAME
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
LABPDB
RACCDB2



PL/SQL procedure successfully completed.

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Final SQL identity and memory verification:

   INST_ID INSTANCE_NAME    STATUS   DATABASE_STATUS
---------- ---------------- ------------ -----------------
     1 RACCDB1      OPEN     ACTIVE
     2 RACCDB2      OPEN     ACTIVE


   INST_ID NAME                                                                 OPEN_MODE
---------- -------------------------------------------------------------------------------------------------------------------------------- ----------
     1 PDB$SEED                                                             READ ONLY
     1 LABPDB                                                               READ WRITE
     2 PDB$SEED                                                             READ ONLY
     2 LABPDB                                                               READ WRITE


   INST_ID NAME
---------- --------------------------------------------------------------------------------
VALUE
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     1 pga_aggregate_target
2147483648

     2 pga_aggregate_target
2147483648

     1 sga_max_size
3221225472

     2 sga_max_size
3221225472

     1 sga_target
3221225472

     2 sga_target
3221225472

     1 use_large_pages
FALSE

     2 use_large_pages
FALSE


8 rows selected.


   INST_ID NAME                                 CON_ID
---------- ---------------------------------------------------------------- ----------
     1 labpdb                                    3
     1 labpdb_app                                    3
     2 labpdb                                    3
     2 labpdb_app                                    3

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Network SQL and documentation capture completed successfully.
```

See [scenario ledger and commands](RAC-POD-EXERCISES.md).

Output presentation: tabs are expanded and trailing padding is removed; raw local logs remain unchanged.
