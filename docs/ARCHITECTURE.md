# Lab architecture and data paths

The diagrams show the **completed OCNE 1.9 foundation**, based on the verified 1 October 2026 run and the checked-in configuration. Added on 8 October; no fresh VM health check is implied. GitHub renders the Mermaid blocks as diagrams.

## VM and cluster layout

```mermaid
flowchart TB
    subgraph HOST["WINDOWS 11 WORKSTATION · VirtualBox 7.2.18"]
        direction TB
        ACCESS["PowerShell + OpenSSH<br/>SSH aliases + pinned keys"]
        subgraph NET["ocne19-net · 192.168.77.0/24 · DHCP off · gateway .1"]
            direction TB
            OP["ocne-op<br/>OCNE operator + NFS<br/>192.168.77.10<br/>4 GiB RAM · 2 vCPUs"]
            subgraph K8S["KUBERNETES CLUSTER · homelab / cluster1"]
                direction TB
                CP["ocne-cp<br/>Control plane<br/>192.168.77.11<br/>8 GiB RAM · 4 vCPUs"]
                W1["ocne-w1 · Worker 1<br/>192.168.77.12<br/>22 GiB RAM · 6 vCPUs"]
                W2["ocne-w2 · Worker 2<br/>192.168.77.13<br/>22 GiB RAM · 6 vCPUs"]
                CP --> W1
                CP --> W2
            end
            OP -.->|"OCNE management"| K8S
        end
        ACCESS -->|"Loopback SSH forwards · 2220–2223 to guest port 22"| NET
        GOLDEN["ol9-golden<br/>Preserved · powered off<br/>Original snapshot chain"]
    end
    classDef host fill:#f1f5f9,stroke:#64748b,color:#0f172a
    classDef operator fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:2px
    classDef control fill:#eff6ff,stroke:#2563eb,color:#1e3a8a,stroke-width:2px
    classDef worker fill:#ecfdf5,stroke:#059669,color:#064e3b,stroke-width:2px
    classDef preserved fill:#f8fafc,stroke:#94a3b8,color:#475569,stroke-dasharray:5 5
    class ACCESS host
    class OP operator
    class CP control
    class W1,W2 worker
    class GOLDEN preserved
    style HOST fill:#ffffff,stroke:#94a3b8
    style NET fill:#f8fafc,stroke:#64748b
    style K8S fill:#ffffff,stroke:#2563eb
```

The separate OCNE operator manages the platform and hosts NFS. It is not a Kubernetes node and is not the Oracle Database Operator. The Kubernetes cluster contains one control-plane node and two workers; its default pod network is Flannel.

All four clones run Oracle Linux 9.8 / UEK R7. Recorded platform versions: OCNE 1.9.6, Kubernetes v1.29.14+2.el9 and CRI-O 1.29.1. New clone VM files and disks are under D:\OCNE19-Lab\vms. The golden VM remains in its original location with its original snapshot chain.

Colors identify roles: orange for the operator, blue for control plane, green for workers, gray for workstation/source. Solid control-plane arrows and dashed OCNE arrows show logical management relationships, not one-way network rules or a complete service-port inventory.

## How Windows SSH reaches the VMs

```mermaid
flowchart LR
    WIN["Windows workstation<br/>Named SSH aliases"]
    CFG["OpenSSH aliases<br/>labadmin + workstation key<br/>Strict host-key checking"]
    WIN --> CFG
    CFG -->|"127.0.0.1:2220"| OP["ocne-op · 192.168.77.10:22"]
    CFG -->|"127.0.0.1:2221"| CP["ocne-cp · 192.168.77.11:22"]
    CFG -->|"127.0.0.1:2222"| W1["ocne-w1 · 192.168.77.12:22"]
    CFG -->|"127.0.0.1:2223"| W2["ocne-w2 · 192.168.77.13:22"]
    classDef client fill:#f1f5f9,stroke:#64748b,color:#0f172a
    classDef operator fill:#fff7ed,stroke:#ea580c,color:#7c2d12
    classDef control fill:#eff6ff,stroke:#2563eb,color:#1e3a8a
    classDef worker fill:#ecfdf5,stroke:#059669,color:#064e3b
    class WIN,CFG client
    class OP operator
    class CP control
    class W1,W2 worker
```

Windows hosts entries resolve each short name and .lab.test FQDN to its actual 192.168.77.x guest address. OpenSSH then uses the alias configuration to connect through the matching loopback forward. Hosts entries alone do not give Windows a direct route into the NAT guest subnet or expose other services.

Inside the lab, guests reach each other directly at their 192.168.77.x addresses. Password-free labadmin SSH was verified for every guest pair, using each guest's own private key and distributed public keys. Sudo remains password-required. This mesh is omitted from the diagram to keep the Windows access path readable.

The shared NAT network provides outbound connectivity via 192.168.77.1; node-to-node traffic stays on the shared guest network. No separate external database access route is configured.

Configuration: [lab.psd1](../config/lab.psd1), [Windows SSH aliases](../config/windows-ssh.conf). Operational details: [SSH access](SSH-ACCESS.md).

## Disks and shared files

```mermaid
flowchart TB
    subgraph OP["ocne-op · NFS server"]
        OBOOT[("100 GiB boot disk<br/>Root XFS")]
        NFS[("100 GiB NFS disk · XFS<br/>Mounted at /srv/nfs<br/>Export /srv/nfs/share")]
    end
    subgraph CP["ocne-cp"]
        CBOOT[("100 GiB boot disk<br/>Root XFS")]
        CMOUNT["/mnt/ocne-share"]
    end
    subgraph W1["ocne-w1"]
        W1BOOT[("100 GiB boot disk<br/>Root XFS")]
        W1DATA[("100 GiB container disk · XFS<br/>/var/lib/containers")]
        W1MOUNT["/mnt/ocne-share"]
    end
    subgraph W2["ocne-w2"]
        W2BOOT[("100 GiB boot disk<br/>Root XFS")]
        W2DATA[("100 GiB container disk · XFS<br/>/var/lib/containers")]
        W2MOUNT["/mnt/ocne-share"]
    end
    NFS <-->|"NFSv4.1 · read/write"| CMOUNT
    NFS <-->|"NFSv4.1 · read/write"| W1MOUNT
    NFS <-->|"NFSv4.1 · read/write"| W2MOUNT
    classDef disk fill:#f1f5f9,stroke:#64748b,color:#0f172a
    classDef share fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:2px
    classDef container fill:#ecfdf5,stroke:#059669,color:#064e3b
    classDef mount fill:#eff6ff,stroke:#2563eb,color:#1e3a8a
    class OBOOT,CBOOT,W1BOOT,W2BOOT disk
    class NFS share
    class W1DATA,W2DATA container
    class CMOUNT,W1MOUNT,W2MOUNT mount
    style OP fill:#fffbeb,stroke:#ea580c
    style CP fill:#eff6ff,stroke:#2563eb
    style W1 fill:#f0fdf4,stroke:#059669
    style W2 fill:#f0fdf4,stroke:#059669
```

Each cylinder is a separate VDI. The four boot disks are independent full clones, enlarged to 100 GiB each; the mounted root XFS filesystem is approximately 99 GiB and includes /var. Each worker's additional 100 GiB container disk is private to that worker.

The operator's additional 100 GiB NFS disk supplies **one shared capacity**, mounted locally at /srv/nfs. The operator accesses /srv/nfs/share directly; the three clients mount that same export at /mnt/ocne-share using NFSv4.1. Bidirectional arrows represent file reads/writes.

NFS access uses labadmin UID/GID 1001, directory mode 0770 and root squashing. SELinux remains Enforcing. The seven clone disks total **700 GiB virtual capacity**, excluding the golden VM and snapshots; dynamic VDI consumption varies.

This is host-level NFS. No Kubernetes PV/PVC, storage provisioner or shared ASM block devices are part of the completed foundation. The independent worker container disks must not be treated as shared RAC disks.

## Operational boundaries

| Area | Recorded configuration |
|---|---|
| Host resources | 61.66 GiB visible RAM; 28 logical processors |
| VM allocation | 56 GiB RAM and 18 vCPUs total; workers remain 22 GiB each |
| Memory exception | Operator 4 GiB / control plane 8 GiB remain below Oracle's published minimums; successful base-lab checks do not establish RAC capacity |
| Startup | Operator first; verify NFS filesystem/export, then start control plane and workers |
| Shutdown | Workers/control plane off before operator |
| Availability | Single Windows host and single control plane; NFS depends on the operator |
| Preserved source | ol9-golden stays powered off during normal lab operation |
| Current RAC phase | Operator, Multus, shared ASM partitions and worker prerequisites prepared; user-supplied image/gold homes and RAC provisioning pending |

Return to [Operating the lab](OPERATING-LAB.md) for commands and checks, or [the detailed run log](CLONING-RUN-LOG.md) for evidence. The [installation guide](OCNE-1.9-OL9-Setup-Guide.md) retains the Oracle sources and original procedure. These diagrams document this lab's local Windows/VirtualBox implementation, not an Oracle certification statement.

## Editing the diagrams

Edit the Mermaid blocks in this file and the overview in [README](../README.md). Keep the overview copies identical. Reconcile names, addresses and allocations against the non-secret config, and disk/service facts against the run log. Do not draw planned RAC components as already installed.

## RAC prerequisites added on 9-10 October

The foundation diagrams above retain the original seven-disk baseline. The current additions below are installed prerequisites; dashed RAC nodes remain **unprovisioned** and will be created by the user later.

```mermaid
flowchart TB
    OPERATOR["Database Operator 2.2.0<br/>Kubernetes controller + cert-manager"]
    subgraph WORKER1["ocne-w1 - 22 GiB / 6 vCPUs"]
        S1[("128 GiB scratch<br/>/scratch - XFS")]
        P1["Future racnode1 pod<br/>16 GiB memory + 2 GiB HugePages<br/>4 CPUs - not provisioned"]
    end
    subgraph WORKER2["ocne-w2 - 22 GiB / 6 vCPUs"]
        S2[("128 GiB scratch<br/>/scratch - XFS")]
        P2["Future racnode2 pod<br/>16 GiB memory + 2 GiB HugePages<br/>4 CPUs - not provisioned"]
    end
    ASM[("Shared ASM01 + ASM02<br/>2 x 50 GiB fixed/shareable VDI<br/>GPT partitions; no ASM disk group yet")]
    N1["Private1 - 192.168.78.0/24<br/>VirtualBox intnet + Multus macvlan"]
    N2["Private2 - 192.168.79.0/24<br/>VirtualBox intnet + Multus macvlan"]
    OPERATOR -.-> P1
    OPERATOR -.-> P2
    P1 -.-> S1
    P2 -.-> S2
    WORKER1 --- ASM
    WORKER2 --- ASM
    WORKER1 --- N1
    WORKER2 --- N1
    WORKER1 --- N2
    WORKER2 --- N2
    classDef future fill:#f8fafc,stroke:#64748b,stroke-dasharray:5 5
    classDef installed fill:#ecfdf5,stroke:#059669,color:#064e3b
    class P1,P2 future
    class S1,S2,ASM,N1,N2,OPERATOR installed
```

Total clone disk virtual capacity is now 1056 GiB: original700 + scratch256 + sharedASM100. The shared100GiB is one capacity visible from both workers, not100GiB per worker. No NFS PV/provisioner was added. All new VDIs remain under project vms/. The Windows host's physical storage consumption differs from dynamic virtual capacity.

For commands and pending artifacts, use the [manual Bash guide](RAC-PREREQUISITES-GUIDE.md) and [provisioning handoff](RAC-PROVISIONING-HANDOFF.md). The gold home/image workflow is user-supplied; no deployment-time RU application is configured.
