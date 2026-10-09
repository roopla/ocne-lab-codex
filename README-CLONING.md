# OCNE 1.9 — golden VM cloning workflow

**Completed lab:** use [Operating the lab](docs/OPERATING-LAB.md). This page explains the build sequence and its recorded adaptations; it is not a request to rebuild existing VMs.

Read [the cloning guide](docs/OCNE-1.9-Golden-VM-Cloning-Guide.md) together with [the OCNE installation guide](docs/OCNE-1.9-OL9-Setup-Guide.md). Detailed results are in [CLONING-RUN-LOG.md](docs/CLONING-RUN-LOG.md).

## Actual sequence and acceptance gates

| Stage | What was done | Evidence required before continuing |
|---|---|---|
| Host/source inspection | Script 00; user selected ol9-golden; inspected source OS, kernel, accounts, network and disks | Confirmed source identity, accessible snapshot chain, eligible OL9/UEK R7 baseline and host capacity |
| Full clones | Script 06, current-state full copies under vms/, requested RAM/CPU | Independent clone media, unique VBox UUID/MAC; source preserved |
| Clone-only boot disk growth | Explicit `-BootDiskMB 102400`, then reviewed growpart/XFS procedure | Root partition start/UUID preserved; ~99 GiB root and sufficient /var free space |
| Identity and networking | Disconnected console preparation; static addresses; labadmin UID/GID 1001 | Unique machine IDs and SSH host keys; console-verified pins; working SSH/sudo and resolution |
| Worker storage | Script 07; separately identified blank 100 GiB disks | Dedicated XFS /var/lib/containers on each worker, persistent after reboot |
| OCNE prerequisites/platform | Guide B1–B14; repositories, firewall, forwarding, packages, certificates and services | Certificate chain/permissions and service checks; preserved enforcing SELinux |
| Kubernetes | Guide C1–C5, homelab/cluster1 | Successful validation/install, node Ready conditions, deployment replicas and pod Ready conditions |
| NFS | Guide Part D; script 05 only while operator off | Identified new disk, mounted XFS before export, all-node writes, root squashing and restart persistence |
| Final acceptance | Operator first on startup, clients first on shutdown | Kubernetes, storage, services and Windows SSH verified after full lab power cycle |

## Source-specific choices

The source was OL9.8 / UEK R7 with a 40 GiB boot disk in a normal snapshot chain. Script 06 supports the inspected full-clone path and explicit boot expansion. Its `DiskMB` configuration field does not implicitly resize cloned disks.

The existing global `Downloads` share was reviewed and preserved using `-ReviewedGlobalShare Downloads`. No source/clone vboxsf mounts were found. VM-specific/transient shares remain rejected. Recheck the mapping and guest access before using that exception for a future build.

The recorded source-specific invocation included `-GoldenVM ol9-golden -ReviewedGlobalShare Downloads -BootDiskMB 102400`, followed by `-Create` only after preflight. These options are now incorporated in the main cloning procedure. The existing destination VMs make creation inappropriate today.

The checked helpers for identity, root growth, worker/NFS formatting and certificate recovery contain observed UUIDs, serials, public keys or process IDs. They are not generic provisioning tools. See [Script reference](docs/SCRIPT-REFERENCE.md) before any execution.

## Important boundaries

- Preserve the golden VM, snapshot chain, unrelated networks and old resources.
- Do not run fresh-ISO scripts 02 or 03.
- Identify each disk by attachment/UUID/serial, size, signatures, partitions and mounts before formatting.
- Keep workers at 22 GiB each. Operator/control-plane 4/8 GiB remain the requested exception below Oracle minimums.
- Read [certificate distribution recovery](docs/CERTIFICATE-DISTRIBUTION.md) before guide B10. Password-free SSH does not make sudo noninteractive.
- Use [SSH access](docs/SSH-ACCESS.md) for the completed Windows aliases and guest mesh.
- Record real results in both execution logs. Existing chronological “pending” notes describe their timestamp, not current completion status.

Both guide HTML files are generated from Markdown with [the renderer](scripts/Render-Documentation.py). The source maps, Oracle attribution and licenses remain in the guides.
