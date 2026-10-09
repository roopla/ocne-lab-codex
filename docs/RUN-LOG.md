# OCNE lab execution record

Status (2026-10-01 22:08 EDT): **cloning, OCNE/Kubernetes, SSH and NFS setup completed and verified after restart**. Detailed evidence, exceptions and chronological errors are in [CLONING-RUN-LOG.md](CLONING-RUN-LOG.md). This is the last recorded live result, not a current health assertion.

| Date/time | Step | Host | Result | Sanitized notes / source |
|---|---|---|---|---|
| 2026-09-30 | Windows inspection | Windows | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-09-30 | Network and VM creation | Windows | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | Cloned OS and prerequisites | All VMs | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | Platform and certificates | Operator / cluster nodes | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | Environment and module deployment | Operator | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | Node verification | Control plane | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | Additional 100 GiB disk / XFS | Windows / operator | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | NFS export / firewall | Operator | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | NFS client mounts / write checks | Control plane / workers / operator | Verified | Cloning workflow; see CLONING-RUN-LOG.md |
| 2026-10-01 | NFS persistence after lab restart | All VMs | Verified | Cloning workflow; see CLONING-RUN-LOG.md |

No fresh OS ISO installation was used. Source OS/kernel, VirtualBox version, installed package versions, final node state and resolved errors are recorded in the detailed cloning log. The nonbootable preparation ISO was local identity tooling, not an OS installer. Do not include credentials, certificates, private keys, tokens, or kubeconfig content. Raw output belongs under ../logs/ and is not committed.

## Historical progress notes

Pending/in-progress statements below describe their timestamp. The completed status and final acceptance above supersede them.

| Date/time | Step | Host | Result | Sanitized notes / source |
|---|---|---|---|---|
| 2026-09-30 20:36:18 -04:00 | Cloning host preflight | Windows | Inspection completed; deployment pending | Script 00 succeeded; nine PowerShell scripts parsed. See CLONING-RUN-LOG.md for observed resources, VM list and pending golden selection. No VM/network changes; scripts 02/03 not executed. |

Cloning progress (2026-09-30): user selected ol9-golden. Inspected VirtualBox configuration and accessible 40 GiB snapshot chain; preserved global Downloads mapping. Corrected script 06 shared-folder guard and validated parsing. Started source console and verified running; guest login/SSH inspection pending. See CLONING-RUN-LOG.md.

2026-10-01: cloning workflow progressed to four distinct networked clones with expanded roots, UID/GID 1001 labadmin and password-required sudo. Dedicated worker XFS prepared with serial/signature guards; restart checks and OCNE platform installation underway. Full actual findings in CLONING-RUN-LOG.md. Cluster and NFS remain pending.

2026-10-01: Windows hosts names corrected; workstation and all-node key SSH verified (see SSH-ACCESS.md). OCNE platform 1.9.6 installed, certificates verified, services active; homelab/cluster1 created and validation passed. Kubernetes installation is still running, with nodes registered and networking initialization pending. NFS pending. See CLONING-RUN-LOG.md for exact results and certificate transport cleanup.

2026-10-01 22:02 EDT: OCNE/Kubernetes installation succeeded, report healthy, all nodes Ready/deployments available. Operator dedicated 100 GiB NFS XFS disk/export and NFSv4.1 client mounts configured. All-node read/write and root-squash checks passed with SELinux Enforcing. Ordered power-cycle persistence verification underway; full details in CLONING-RUN-LOG.md.

2026-10-01 22:08 EDT: final ordered power-cycle checks passed: all three Kubernetes nodes Ready, all15 pods Running/Ready, all deployments available. Operator XFS and all NFSv4.1 client mounts persisted. Existing files and fresh writes verified across all four nodes; root squashing and SELinux retained. Source preserved, exact resources retained, Windows hosts and key SSH verified. No Git commit/push. See OPERATING-LAB.md and SSH-ACCESS.md.

## Documentation reconciliation — 2026-10-08

User requested completion of the OCNE documentation before Database Operator/RAC work. README, cloning overview, operations, SSH access and both guide sources were reconciled with recorded evidence. Added certificate recovery, troubleshooting and script execution boundaries. Preserved historical run entries, Oracle sources/attribution and the OP/CP memory exception. Originals were backed up locally under logs/documentation-before-20261002-081920. Printable guide regeneration and static validation are the remaining documentation checks at this entry; no new VM/cluster execution or RAC preparation occurred.

### Documentation checks completed — 2026-10-08

Both printable HTML guides were regenerated from the corrected Markdown using project-local Markdown 3.7 and scripts/Render-Documentation.py. Static checks passed: 12 Markdown documents, 54 local links, matching source/HTML, preserved fenced command text, heading IDs, project paths and UTF-8. All 32 documented PowerShell blocks and 13 existing PowerShell helpers parsed successfully; all 79 documented Bash blocks passed local bash -n without executing their contents. Original guide source URLs and attribution/license text were retained. Documentation credential-pattern scanning found no matches; this is a limited pattern check, not a complete secret audit.

Reviewed changes against the saved pre-edit documentation because the project has no Git repository; no staging, commit or push occurred. Original files remain under logs/documentation-before-20261002-081920. A machine-readable documentation validation record and final file hashes are under logs/documentation-validation-20261008.json.

The documentation task is complete. This revision made documentation/tooling changes only; it did not execute VM/cluster setup, change disks/networks/credentials, or begin Database Operator/RAC. Last live lab acceptance remains 2026-10-01, not this documentation date. Use OPERATING-LAB.md to check health when returning.

## GitHub publication preparation — 2026-10-08

User authorized pushing to https://github.com/roopla/ocne-lab-codex.git. Initialized the local Git repository on main and configured that URL as origin. Remote reference inspection returned no existing refs. Confirmed ignore rules exclude actual workstation keys, encrypted credentials, VM disks, ISO media and logs; added an extension rule for protected PowerShell credential exports outside private/. Reviewing an explicit allowlist of documentation, configuration, helper scripts and empty folder markers before the initial commit. Push success is not yet claimed at this entry.

## GitHub publication verified — 2026-10-08

Pushed initial commit 1186940765d3bd2ddb49fd30ed06eef13f9f7530 to the user-authorized repository https://github.com/roopla/ocne-lab-codex.git, branch main. A separate git ls-remote check confirmed remote main matched the local commit. The initial commit contains 94 reviewed files (documentation, non-secret configuration, helpers and empty folder markers). VM disks, ISO/preparation media, raw logs, protected credentials and private keys were excluded. Staged allowlist/credential-pattern checks and git diff --cached --check passed; the documentation consistency check passed. The local main branch tracks origin/main. This follow-up entry records the verified initial publication; no VM or cluster operations were performed.
