# OCNE 1.9 lab — D:\OCNE19-Lab

The cloning lab was completed and verified on **1 October 2026 at 22:08 EDT**, including an ordered power cycle. The subsequent OCNE report completed at 22:10. This documentation was reconciled with those results on 8 October; that is a documentation review date, not a new live health check.

Start with [Operating the lab](docs/OPERATING-LAB.md) for normal use. **Do not rerun VM creation, identity reset, formatting, or cluster installation on the completed lab.** Database Operator and RAC remain a separate, paused task.

## Documentation map

| Document | Use |
|---|---|
| [Operating the lab](docs/OPERATING-LAB.md) | Access, startup, shutdown, health checks, storage and credential locations |
| [SSH access](docs/SSH-ACCESS.md) | Windows hosts, NAT forwarding, guest mesh and pinned keys |
| [Cloning entry point](README-CLONING.md) | Build sequence and the actual source adaptations |
| [Golden VM cloning guide](docs/OCNE-1.9-Golden-VM-Cloning-Guide.md) | Source inspection, full clones, unique identities and storage |
| [OCNE installation guide](docs/OCNE-1.9-OL9-Setup-Guide.md) | Oracle's full Installation procedure, linked Kubernetes continuation and separate NFS addition |
| [Certificate distribution recovery](docs/CERTIFICATE-DISTRIBUTION.md) | Privilege prerequisites, preserved PKI, observed recovery and verification |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Actual hiccups, resolutions and the unresolved report discrepancy |
| [Script reference](docs/SCRIPT-REFERENCE.md) | Execution contexts, one-time helpers and historical recovery scripts |
| [Execution summary](docs/RUN-LOG.md) | Completed stages and documentation changes |
| [Detailed cloning log](docs/CLONING-RUN-LOG.md) | Chronological evidence, errors, adaptations and final acceptance |

Printable copies: [cloning guide](docs/OCNE-1.9-Golden-VM-Cloning-Guide.html) and [installation guide](docs/OCNE-1.9-OL9-Setup-Guide.html). They are generated from the Markdown sources; edit Markdown first.

## Verified baseline

| VM | Lab address | RAM | vCPUs | Independent virtual disks |
|---|---|---:|---:|---|
| ocne-op | 192.168.77.10 | 4 GiB | 2 | 100 GiB OS + 100 GiB NFS |
| ocne-cp | 192.168.77.11 | 8 GiB | 4 | 100 GiB OS |
| ocne-w1 | 192.168.77.12 | 22 GiB | 6 | 100 GiB OS + 100 GiB container XFS |
| ocne-w2 | 192.168.77.13 | 22 GiB | 6 | 100 GiB OS + 100 GiB container XFS |

All names also use `.lab.test`. NAT network: `ocne19-net`, `192.168.77.0/24`, gateway `.1`, DHCP disabled. Windows SSH uses loopback ports 2220–2223 through [the alias configuration](config/windows-ssh.conf).

Observed software: Oracle Linux 9.8, UEK R7 `5.15.0-324.217.5.3.el9uek.x86_64`, OCNE 1.9.6, Kubernetes `v1.29.14+2.el9`, CRI-O 1.29.1. The golden VM `ol9-golden` and its snapshot chain were preserved.

The Windows host reports 28 logical processors and 61.66 GiB visible physical RAM. VM allocations total 56 GiB and 18 vCPUs, leaving about 5.66 GiB of nominal visible RAM capacity for Windows/overhead; actual free memory varies. Successful base-lab checks do not establish workload capacity. Operator/control-plane allocations remain below Oracle's published 8/16 GB minimums; no OOM was observed during the recorded acceptance checks. See [Oracle host requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html).

## Project storage and secrets

| Path | Contents | Track in Git? |
|---|---|---|
| docs/, config/, scripts/, README files | Sanitized documentation, local configuration and helpers | Review first |
| ISO/ | ISO/preparation media | No, except folder marker |
| vms/ | Clone VM configuration and disks | No |
| logs/ | Raw execution output and local documentation backups | No |
| private/ | SSH keys, encrypted credentials and local tooling | No |

All new lab VM disks are under this project. VirtualBox global registration and the existing golden VM retain their original Windows locations. Linux state, platform certificates and the Kubernetes administrator kubeconfig reside inside guests.

The operator's separate 100 GiB NFS filesystem is mounted at `/srv/nfs`, exporting `/srv/nfs/share`. Clients mount `/mnt/ocne-share`; `labadmin` UID/GID 1001 has read/write access. Root squashing and SELinux remain enabled. No Kubernetes PV/PVC, provisioner, ASM storage, Database Operator or RAC deployment was added.

## Build and maintenance boundaries

The completed lab used the cloning workflow. Scripts **02 and 03 were not used and must not be run for this workflow**. The installation guide retains Part A as an explicitly separate fresh-ISO reference; its creation blocks are not instructions for the existing clones.

Windows/VirtualBox orchestration is local implementation. Linux/OCNE operations follow the cited Oracle Installation manual and its Kubernetes continuation. NFS is a separately sourced Oracle Linux addition. Source attribution and licensing remain in both guides.

For future work, first inspect the host and existing resources, parse any PowerShell scripts being changed or run, and read the relevant helper. Resume necessary steps from observed state. Do not delete/recreate resources to resolve conflicts.

## Documentation maintenance

Regenerate the printable guides from the project root:

```powershell
python -m pip install --disable-pip-version-check --no-cache-dir --target D:\OCNE19-Lab\private\doc-tools Markdown==3.7
python .\scripts\Render-Documentation.py
python .\scripts\Render-Documentation.py --check
```

The renderer only writes the two guide HTML files. Its dependency is installed locally under ignored `private/`. Check mode validates source/HTML agreement, local Markdown links, balanced code fences, and stale project paths; it does not execute guest commands.

## Git and GitHub

The user authorized publication to [roopla/ocne-lab-codex](https://github.com/roopla/ocne-lab-codex) on 8 October 2026. The local repository uses branch main and that URL as origin. Publication outcomes are recorded in the run logs.

Only reviewed documentation, non-secret configuration, helper scripts and empty directory markers belong in Git. Runtime folders and common credential/media formats are excluded by .gitignore. Exclusions are not a credential scanner or a backup.

From the project root, review changes before each commit:

```powershell
git status --short --untracked-files=all
git check-ignore -v vms/ocne-op/ocne-op.vdi private/workstation_ed25519
git diff
git diff --cached --name-only
git diff --cached
```

Never stage passwords, CA/private keys, kubeconfigs, raw credentials, logs or VM media. Review filenames and content rather than using a blanket add command. Back up guest state and NFS data separately; cloning this repository restores procedures and helpers, not a running lab.

A future push to a different destination requires the user's authorization. Use the operating runbook for these existing VMs; publishing the documentation does not authorize rerunning creation/formatting scripts.
