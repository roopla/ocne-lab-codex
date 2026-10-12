# Pod, network and storage precheck output

[Operations chapter](MANUAL-04-RAC-OPERATIONS.md) | [Scenario workbook](RAC-POD-EXERCISES.md)

This capture stopped with exit2 at the missing GI recovery-directory check. It is a FAILED restart prerequisite, not a failed running database. Later commands were not run by this invocation.

Complete command output, 11 October 2026; tabs expanded only for rendering. The collector prints argument lists joined with spaces; copy the properly quoted commands from the workbook rather than treating every printed argument list as a new shell command. No Secret values are included.

```text
Captured UTC: 2026-10-11T19:04:06.705728+00:00

SCENARIO A: pod identity, placement, resource and readiness inventory

$ kubectl -n rac get pods -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName,PHASE:.status.phase
NAME         UID                                    NODE               PHASE
racnode1-0   0ad8f3ab-5b3c-4ca4-bf74-a9510a653bc4   ocne-w1.lab.test   Running
racnode2-0   fb9bdc6d-2737-4291-bedd-121e30724c0a   ocne-w2.lab.test   Running
Exit code: 0
Pod readiness/probes: racnode1-0
{
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
  "containers": [
    {
      "name": "racnode1-0",
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
      "livenessProbe": null,
      "startupProbe": null
    }
  ]
}
Pod readiness/probes: racnode2-0
{
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
  "containers": [
    {
      "name": "racnode2-0",
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
      "livenessProbe": null,
      "startupProbe": null
    }
  ]
}
Desired StatefulSet: racnode1
{
  "strategy": {
    "type": "OnDelete"
  },
  "replicas": 1,
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
    }
  ],
  "containers": [
    {
      "name": "racnode1-0",
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
      "pdbEnvironment": [
        {
          "name": "ORACLE_PDB_NAME",
          "value": "LABPDB"
        }
      ]
    }
  ]
}
Desired StatefulSet: racnode2
{
  "strategy": {
    "type": "OnDelete"
  },
  "replicas": 1,
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
    }
  ],
  "containers": [
    {
      "name": "racnode2-0",
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
      "pdbEnvironment": [
        {
          "name": "ORACLE_PDB_NAME",
          "value": "LABPDB"
        }
      ]
    }
  ]
}

SCENARIO B: network Services and endpoints

$ kubectl -n rac get services -o wide
NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE   SELECTOR
racnode-scan        ClusterIP   None             <none>        <none>            16h   app=oracle-database-operator,database.oracle.com/component=RAC,database.oracle.com/managed-by=racdatabase-controller,database.oracle.com/name=rac19c
racnode-scan-lsnr   NodePort    10.104.49.126    <none>        1521:31521/TCP    16h   statefulset.kubernetes.io/pod-name=racnode1-0
racnode1-0          ClusterIP   None             <none>        <none>            16h   statefulset.kubernetes.io/pod-name=racnode1-0
racnode1-0-lsnr     NodePort    10.96.75.114     <none>        31522:31522/TCP   16h   statefulset.kubernetes.io/pod-name=racnode1-0
racnode1-0-ons      NodePort    10.96.6.122      <none>        6200:30200/TCP    16h   statefulset.kubernetes.io/pod-name=racnode1-0
racnode1-0-vip      ClusterIP   None             <none>        <none>            16h   statefulset.kubernetes.io/pod-name=racnode1-0
racnode2-0          ClusterIP   None             <none>        <none>            16h   statefulset.kubernetes.io/pod-name=racnode2-0
racnode2-0-lsnr     NodePort    10.102.225.198   <none>        31523:31523/TCP   16h   statefulset.kubernetes.io/pod-name=racnode2-0
racnode2-0-ons      NodePort    10.108.138.93    <none>        6200:30201/TCP    16h   statefulset.kubernetes.io/pod-name=racnode2-0
racnode2-0-vip      ClusterIP   None             <none>        <none>            16h   statefulset.kubernetes.io/pod-name=racnode2-0
Exit code: 0

$ kubectl -n rac get endpointslices -o wide
NAME                      ADDRESSTYPE   PORTS     ENDPOINTS               AGE
racnode-scan-lsnr-69b7l   IPv4          1521      10.244.1.9              16h
racnode-scan-rdnd2        IPv4          <unset>   10.244.1.9,10.244.2.9   16h
racnode1-0-g4fqn          IPv4          <unset>   10.244.1.9              16h
racnode1-0-lsnr-4xgbj     IPv4          31522     10.244.1.9              16h
racnode1-0-ons-m2bzz      IPv4          6200      10.244.1.9              16h
racnode1-0-vip-vzq69      IPv4          <unset>   10.244.1.9              16h
racnode2-0-bkhwr          IPv4          <unset>   10.244.2.9              16h
racnode2-0-lsnr-2qfjx     IPv4          31523     10.244.2.9              16h
racnode2-0-ons-lptmc      IPv4          6200      10.244.2.9              16h
racnode2-0-vip-lt29w      IPv4          <unset>   10.244.2.9              16h
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- ip -br address
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0@if14        UP             10.244.1.9/24 fe80::ef:c7ff:fe1b:4353/64
ens1@if3         UP             192.168.78.120/24 169.254.13.148/20 fe80::4c23:e2ff:fea7:c48a/64
ens2@if4         UP             192.168.79.120/24 169.254.31.123/20 fe80::2877:78ff:fe7e:4eb4/64
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- ip route
default via 10.244.1.1 dev eth0
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.9
169.254.0.0/20 dev ens1 proto kernel scope link src 169.254.13.148
169.254.16.0/20 dev ens2 proto kernel scope link src 169.254.31.123
192.168.78.0/24 dev ens1 proto kernel scope link src 192.168.78.120
192.168.79.0/24 dev ens2 proto kernel scope link src 192.168.79.120
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode2-0 -- ip -br address
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0@if14        UP             10.244.2.9/24 fe80::1466:bdff:fecd:7ab3/64
ens1@if3         UP             192.168.78.121/24 169.254.14.67/20 fe80::a0af:c0ff:fef6:58bd/64
ens2@if4         UP             192.168.79.121/24 169.254.25.117/20 fe80::1425:d7ff:fe82:590d/64
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode2-0 -- ip route
default via 10.244.2.1 dev eth0
10.244.0.0/16 via 10.244.2.1 dev eth0
10.244.2.0/24 dev eth0 proto kernel scope link src 10.244.2.9
169.254.0.0/20 dev ens1 proto kernel scope link src 169.254.14.67
169.254.16.0/20 dev ens2 proto kernel scope link src 169.254.25.117
192.168.78.0/24 dev ens1 proto kernel scope link src 192.168.78.121
192.168.79.0/24 dev ens2 proto kernel scope link src 192.168.79.121
Defaulted container "racnode2-0" out of: racnode2-0, racnode2-init1 (init)
Exit code: 0

SCENARIO C: persistent storage and GI restart prerequisites

$ kubectl get pv
NAME                     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
asm-pv-16e0716b-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-16e0716b-rac19c                  <unset>                          16h
asm-pv-ee86c2c9-rac19c   49Gi       RWX            Retain           Bound    rac/asm-pvc-ee86c2c9-rac19c                  <unset>                          16h
Exit code: 0

$ kubectl -n rac get pvc
NAME                      STATUS   VOLUME                   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
asm-pvc-16e0716b-rac19c   Bound    asm-pv-16e0716b-rac19c   49Gi       RWX                           <unset>                 16h
asm-pvc-ee86c2c9-rac19c   Bound    asm-pv-ee86c2c9-rac19c   49Gi       RWX                           <unset>                 16h
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- df -hT /u01 /dev/shm
Filesystem     Type   Size  Used Avail Use% Mounted on
/dev/sdc       xfs    128G   53G   76G  41% /u01
tmpfs          tmpfs   19G  1.4G   17G   8% /dev/shm
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
Exit code: 0

$ kubectl exec -n rac racnode1-0 -- ls -ld /u01/app/grid/.etcoraclebackup /u01/app/grid/.etcoraclebackup/oracle /etc/oracle /u01/app/19c/grid /u01/app/oracle/product/19c/dbhome_1
drwxr-xr-x.  6 root   oinstall  151 Oct 11 02:34 /etc/oracle
drwxr-xr-x. 89 root   oinstall 4096 Oct 11 02:33 /u01/app/19c/grid
drwxr-xr-x. 74 oracle oinstall 4096 Oct 11 14:19 /u01/app/oracle/product/19c/dbhome_1
Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
ls: cannot access '/u01/app/grid/.etcoraclebackup': No such file or directory
ls: cannot access '/u01/app/grid/.etcoraclebackup/oracle': No such file or directory
command terminated with exit code 2
Exit code: 2
```

Output presentation: tabs are expanded and trailing padding is removed; raw local logs remain unchanged.
