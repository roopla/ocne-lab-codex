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

## Architecture diagrams — 2026-10-08

Added a GitHub Mermaid overview to README and a detailed docs/ARCHITECTURE.md with VM topology, Windows SSH forwarding and disk/NFS views. The overview copies match; node IPs, 4/8/22/22 GiB RAM, 2/4/6/6 vCPUs, ports 2220-2223 and seven 100 GiB disks were checked against configuration and recorded build evidence. Three unique diagrams rendered successfully with local Mermaid CLI 12.0.0/headless Edge and were visually inspected; previews and tooling remain under ignored logs/ and private/. The figures distinguish the separate OCNE operator VM from the future Database Operator, preserve the golden source and identify RAC/ASM/Multus as not yet deployed. Documentation only; no VM state changed or new live health result claimed.

## RAC media preflight and lab recovery started - 2026-10-09

User identified ISO/ as the downloaded media location and authorized continuing setup without routine confirmations. Read-only archive checks completed for all five ZIP files: Database/Grid base 19c media, GI RU 39467003 and Database RU 39472050 (both 19.32.0.0.260721), and OPatch 12.2.0.1.53. Both RU readmes require OPatch 12.2.0.1.52 or later. ZIP CRC checks passed and local SHA256 fingerprints were saved in logs/rac-media-inventory.json; no comparison against Oracle-published checksums or installation was performed.

Preflight found the existing lab degraded: worker2 NotReady and SSH reset, console kernel soft lockups/RCU timer stalls, large time offsets in the other guests, and systemd watchdog/core-dump records. Preserved guest diagnostics and VirtualBox logs under ignored logs/. Windows time service also reported unsynchronized. Root cause is not established; no evidence proves insufficient RAM or host sleep caused this incident. No clocksource, kernel, memory, firewall or SELinux policy was changed.

Operator NIC2 was observed bridged with DHCP address 192.168.137.229, in addition to the recorded 192.168.77.10 lab NIC. This was not in the previous documented baseline and was preserved. The user-added nginx pod was already Terminating on worker2 and was not manually deleted.

Started ordered recovery: scheduled graceful worker1/control-plane shutdowns, sent worker2 ACPI shutdown and inspected its unresponsive console. Worker2 remained running after the graceful request; verified its UUID d4404167-3980-4c69-ae11-9b1e7125446e and forced only that VM off. All disks retained. Other client shutdown and restart acceptance remain pending at this entry. No Database Operator, cert-manager, Multus, ASM disk, PV/PVC or RAC deployment has been installed by this preflight.

## Modern Standby diagnosis and RAC hardware preflight - 2026-10-09 evening

The initial recovery completed: control plane and worker1 shut down cleanly; worker2 required the recorded forced poweroff. Worker1 was briefly started through the GUI externally, then shut down cleanly again before operator shutdown. Operator shut down cleanly and restarted with its expected NFS UUID and active API/NFS services. Control plane and both workers subsequently restarted.

A later check found fresh time jumps. Windows Kernel-Power events 506/507 establish Modern Standby from 09:32 to 19:36 and 20:37 to 21:47 EDT; guest clock jumps and soft-lockup messages coincide with resume, and VirtualBox records large timer catch-up losses. This is direct evidence of host standby interrupting the guests, replacing the earlier uncertainty. Saved Windows events and prior power settings under logs/. Changed only active-plan AC sleep timeout from 3600 seconds to 0 (never); DC remains 180 seconds. Explicit sleep/hibernate and battery sleep still require an orderly lab shutdown.

Windows w32tm resync was attempted but denied administrator access. A direct query of its configured time server measured roughly 75 ms offset; this does not prove its time service synchronized. Guest Chrony recovered source selection after resume; requested fresh samples with chronyc burst and verified offsets below 100 ms on all four. No NTP source/configuration or clocksource change, manual time step, kernel change or watchdog disabling was applied.

The strict full-boot Verify-Recovery-Time.sh check correctly fails on the preserved standby-related soft-lockup records, even though synchronization passes. Separate post-mitigation journal checks showed no new warnings in the checked interval. At 21:54 EDT all three Kubernetes nodes, all 15 pods and all four deployments passed readiness; fresh all-node NFS writes/reads passed with UID/GID1001, original mounts/UUIDs and SELinux Enforcing. This is a bounded recovery result, not long-term stability or RAC capacity validation.

Reviewed and parsed scripts/08-Prepare-RAC-Hardware.ps1; its read-only preflight passed for both exact worker UUIDs, original boot/container disks, unchanged 22 GiB/6 CPU allocations, empty SATA3/4/5 and NIC2/3, unused internal-network names and sufficient D: storage. Planned additions: one independent 128 GiB scratch VDI per worker, two new 50 GiB fixed/shareable ASM VDIs under vms/rac-shared, and isolated internal networks ocne-rac-priv1/ocne-rac-priv2. The unrelated existing D:\VMs\shared\asm3.vdi is excluded. Worker graceful shutdowns scheduled before applying; hardware creation/guest initialization not yet complete at this entry.

## RAC infrastructure and prerequisite preparation - 2026-10-09 to 2026-10-10

Hardware preparation completed with both workers powered off. The script initially refused to change anything while worker2 was still shutting down; it succeeded after the powered-off check passed. Each worker received a new 128 GiB scratch disk, and both received the same two new 50 GiB fixed/shareable ASM disks. VM RAM remains 22 GiB and CPU count 6 per worker. Original disks, golden VM, unrelated shareable disk and operator bridged NIC were preserved. Hardware inventory and pre-change VM configurations are under logs/.

Scratch filesystems were identified by new disk serials and mounted at /scratch using UUIDs: worker1 48e2e0e8-d37d-4262-a2d3-67b40eacf76b; worker2 8d744a6a-39bf-4cb4-9ab3-739dbff7c319. The initial scratch helper had an incorrect wipefs option (-o TYPE, interpreted as offset) inside a substitution that masked its error. Independent pre-format inspection had already established the exact new disks were blank, and serial/size/mount guards plus non-forcing mkfs protected existing disks. Corrected the helper to capture the result of wipefs --output TYPE in a standalone, fail-closed assignment; subsequent signature verification passed. No existing filesystem was reformatted. This failure and its correction are retained here.

The shared disks were partitioned exactly once on worker1 and reread on both workers. Partition labels ocne-rac-asm01 and ocne-rac-asm02 have PARTUUIDs c25151a5-4557-444f-916f-cc359f3fd43b and 14cb5bdb-e6ff-4706-b82f-b0f748df5157 respectively. Header hashes matched across workers. No filesystem, ASM disk group or Kubernetes PV/PVC was created. Device letters changed on worker2 after adding disks, confirming why serials/UUIDs are required.

Added worker-only VirtualBox internal networks ocne-rac-priv1 and ocne-rac-priv2 on NIC2/NIC3, with allow-vms promiscuous policy. Guest enp0s8/enp0s9 have MTU1500 and no host IPs. Installed OCNE Multus module rac-multus through olcnectl; its daemonset became 3/3 Ready. Created namespace rac and the two macvlan network attachment definitions for 192.168.78.0/24 and 192.168.79.0/24.

Network testing first failed because CRI-O's diagnostic container lacked NET_RAW; adding that capability exposed a separate unicast delivery failure. Enabling guest NIC promiscuous reception fixed packet delivery. Persisted NetworkManager accept-all-mac-addresses=1 only on the two dedicated private profiles. NetworkManager could not reapply this property in place, so runtime state was set using ip link; persistent activation is checked separately. At 08:30 EDT on 10 October, both directions passed on both private networks using 1472-byte ICMP payloads at MTU1500, and Kubernetes DNS resolved from both test pods. Test pods were subsequently removed.

All five media files passed destination SHA256 verification on both workers. GI RU contents and OPatch ZIP were staged under /scratch/software/stage/19c/19.32; extraction did not execute an installer. The user then specified that they will supply and pre-stage the slim image and fully patched GI/database gold homes. The provisioning manifest now uses /scratch/software/stage/19c/19.32-gold and has no RU/OPatch/one-off application fields. The previous base/RU files remain unused and preserved.

Applied Oracle's documented worker sysctls and rac-ocne SELinux module, retained Enforcing, configured recursive container_file_t contexts for only the RAC home/stage paths, created home directories with numeric owner 54321:54321, enabled the documented unsafe sysctls in kubelet, and disabled THP at runtime and in boot entries. Backups are under guest /var/opt/ocne-rac-backup-<timestamp>. TSC was already active and was not changed. Initially reserved 6 GiB HugePages, then reduced the unused reservation to 2 GiB after inspecting the operator's mandatory 16 GiB ordinary-memory limit. Final pod budget is 16 GiB ordinary memory plus 2 GiB HugePages and 4 CPUs; SGA1G/PGA2G is a constrained lab profile, not validated RAC capacity. Worker memory allocation remains unchanged.

Installed cert-manager v1.17.4 and verified all three deployments Ready. This release is compatible with Kubernetes1.29 but is outside community maintenance; the fixed OCNE1.9 lifecycle limitation is documented. Installed Oracle Database Operator2.2.0 using namespace-scoped watch access for rac and oracle-database-operator-system, one lab replica, and an amd64 image digest pinned from the registry. Added the source's required Multus/PV/node read RBAC. The controller and both certificates became Ready. Created the RAC password and SSH secrets without printing their contents; protected recovery material is on ocne-cp under /home/labadmin/.local/share/ocne-rac-secrets (directory0700, secret files0600). Labeled only the two workers raccluster=raccluster01.

config/rac-database.yaml passed the installed operator's server-side create dry-run on 10 October. It has not been applied; kubectl get racdatabases -A returned no resources. Image reference and actual gold ZIP contents are pending user-supplied artifacts. Latest CVU host validation has not run because the CVU package is absent. Whether any release-specific recommended fixes are included in the supplied gold homes remains to be verified. Worker reboot/persistence acceptance is in progress at this entry.

## Final prerequisite acceptance and CVU - 2026-10-10

Gracefully rebooted workers one at a time. Worker1 boot changed from edd15747-c132-475d-95b1-14a19649f96a to f8489ae9-4b58-4c97-aae6-2812387ea5ef; worker2 from 5aa31ca8-7bde-413a-a265-350004997df0 to 8bd944ff-6866-4528-8541-0bc43c6aa2a3. Both passed persistent scratch/container mount UUIDs,2GiB HugePages, THP never, SELinux Enforcing/module/contexts, kubelet/sysctls, TSC, Chrony synchronization, private NIC PROMISC and service checks. Shared partition UUIDs and header hashes still matched and no filesystem signatures were present. The controller and cert-manager recovered after the worker restarts.

The final diagnostic pods used node selectors (not nodeName) to test actual scheduler placement with4CPU,16GiB ordinary memory and2GiB HugePages per worker. Both became Ready; hugetlbfs mounts, pod shmmax, both directions on both private networks at1472-byte payload and DNS passed. A BusyBox stat check initially returned UNKNOWN for hugetlbfs; corrected the verification to read /proc/mounts and repeated successfully. Removed only the named diagnostic pods. Fresh all-four-node NFS writes/reads passed at08:53 EDT with UID/GID1001. At08:57, all three Kubernetes nodes and every current deployment/pod passed readiness. Final RAC manifest server-side dry-run passed again; no RacDatabase, PV or rac PVC existed.

The user then supplied CVU. Inspected cvupack_linux_ol8_x86_64.zip (133049247 bytes, SHA25623da73fed4b9403f933a5bbb8e75e9b6931ed5fd33fd1dbfc6503227de70bdc8), verified all317 member CRCs and safe archive paths, and verified copied hashes on both workers. Package README identifies July2026 and OL8/OL9/RHEL8/RHEL9. Actual tool version is23.26.3.0.0, build090726x8664. Ran cluvfy comp containerhost -type k8 -verbose -text -savedir as labadmin independently on each worker, without fixups or release-switch guessing. Both completed successfully with exit0 at09:01 EDT. Reports and exact Bash reproduction are recorded in docs/RAC-CVU-RESULTS.md. The public Oracle landing-page fingerprint differed; no publisher-checksum match was claimed.

Remaining user-owned inputs are the OL9 slim image pre-staged in both CRI-O image stores, its exact image reference, and fully patched GI/database gold home ZIPs with verified contents/hashes. The YAML is prepared for gold homes and contains no deployment-time RU/OPatch/one-off fields. These artifact checks and actual database acceptance remain pending. RAC has not been provisioned. The manual guide includes direct Bash guest commands and a syntax-checked Git Bash equivalent for Windows VirtualBox orchestration; that alternative was not executed as a second build.


## Documentation handoff verification - 2026-10-10 evening

At20:38 EDT, a fresh check still showed all three Kubernetes nodes Ready, every current pod Ready, no RacDatabase resources, and normal Chrony leap status with sub-millisecond offsets on all four guests. This records the later observation separately from the morning prerequisite tests.

Manual documentation now includes23 syntax-checked Bash blocks, guest commands, Git Bash host equivalents, CVU reproduction, artifact staging and the separate user-only apply step. All83 Bash scripts and14 PowerShell files parsed;17 Markdown documents and113 local links passed the documentation validator. Vendor YAML was parsed and checked to contain no Secret, RacDatabase, PV or PVC objects; licenses/provenance and hashes are included. The new architecture diagram rendered and was visually checked. Raw reports, credentials, media and VM disks remain outside tracked assets.

## Supplied RAC image and gold homes staged — 2026-10-10 evening

At 21:32–21:40 EDT, inspected current host/VM/network state and confirmed all three Kubernetes nodes Ready. Golden/unrelated assets were unchanged. Pulled docker.io/roopla/oracle-rac:19.3.0-slim into both rootful CRI-O stores; both resolved to sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d. Static image inspection found OL9.8/amd64, expected Oracle identities, systemd and RAC controller scripts; 19 Python scripts parsed. No entrypoint was executed.

Both supplied oracle-dbhome-19.32.zip and oracle-gridhome-19.32.zip passed full source CRC, member-path and stable-source checks. Archived inventories identify 19.32 and OPatch 12.2.0.1.53. Copied both files to each worker, checked scratch UUIDs and all destination SHA256 values, then verified owner 54321:54321, mode 0755 and container_file_t. Each scratch filesystem retains about 101 GiB free. Exact fingerprints and patch records are in [artifact acceptance](RAC-ARTIFACT-ACCEPTANCE.md). No installer was executed and no home was extracted.

Updated config/rac-database.yaml to the immutable image digest and actual gold ZIP names, retaining no RU/OPatch/one-off fields. Copied the exact YAML to ocne-cp; server-side create dry-run passed at 21:39. No RacDatabase, PV or rac PVC exists. DBCA fix 34436514 is not listed in the supplied archived inventories; asked for source-build or Oracle Support evidence of 19.32 inclusion/supersedence/applicability. This remains an open pre-deployment check, not proof that the fix is required or absent from the binaries. Updated manual PowerShell/Bash instructions and current readiness statements; historical pending entries above remain chronological. RAC provisioning remains exclusively the user's next action.

Final 21:46 EDT cluster check passed: all three nodes, all eight deployments and all 22 current pods Ready. Image environment contains no deployment-time patch inputs. Documentation validation passed for 18 Markdown files and 128 local links; the five added Bash scripts, gold inspector Python AST, YAML and 26 RAC documentation Bash blocks passed syntax checks. Windows/control-plane manifest SHA256 matched: 4e4e863fdaf0c4a57190911dedb8b5479b00978baf8d1a6a22d9d587017e5291.

## RAC manifest provenance documented - 2026-10-10 21:51 EDT

At the user's request, added the exact pinned Oracle 2.2.0 racdb_prov.yaml source, linked API/admission/controller references, and a sample-versus-lab adaptation table to docs/RAC-PROVISIONING-HANDOFF.md. Recorded the image, gold-home, storage, network, secret, resource and database choices, plus prior validation and its limits. This update changes documentation only; the manifest and live cluster were not changed or applied.

## DBCA prerequisite decision - 2026-10-10 21:56 EDT

The user confirmed that DBCA fix 34436514 is unnecessary for the supplied 19.32 home. Closed the remaining prerequisite question based on that owner confirmation, without claiming independently verified Oracle Support applicability or binary supersedence. Updated current readiness, artifact acceptance and handoff documentation; historical entries above retain the earlier unresolved state. No patch was applied, no manifest or artifact changed, and no RAC provisioning was performed. The user retains the provisioning step following their YAML review.

## SGA increase and sizing inspection - 2026-10-10 21:59 EDT

Increased manifest SGA from 1G to 2G per instance following the user's request; PGA remains 2G. Verified both workers report 1024 free two-MiB HugePages and Kubernetes advertises 2Gi HugePages. The installed operator's source requires HugePages at least equal to SGA and accepts this configuration. Copied the updated YAML to ocne-cp and successfully ran server-side create dry-run. Both manifest copies have SHA256 01e10e9c9fef99fc07a34c8f8a5d51f5a2b4b2fe825f8f11ef362484d082fe85. No RacDatabase resource exists; no guest settings were changed. Updated current sizing documentation while retaining historical results.

For the user's maximum-SGA question, observed worker1 ordinary allocatable memory 19909396Ki and existing pod requests 520Mi. A hypothetical increase from 2Gi to 4Gi HugePages would leave about 490.77Mi ordinary scheduling headroom after a 16Gi RAC pod request. This is an accounting estimate, not validated runtime capacity; some existing pods have no memory requests. Suggested 3Gi as a more conservative next increase. Any increase beyond the current 2Gi needs corresponding host/pod HugePages and sysctl changes and fresh scheduling/guest checks. No 3Gi/4Gi change was performed.

## SGA 3 GiB and matching HugePages - 2026-10-10 22:01-22:08 EDT

The user authorized 3 GiB SGA per RAC instance. Updated sgaSize to 3G, HugePages request/limit to 3Gi, TOTAL_MEMORY to 19456 MiB, kernel.shmmax to 3221225472 bytes and kernel.shmall to 786432 four-KiB pages. PGA remains 2G, ordinary pod memory 16Gi, CPU 4 and worker RAM 22Gi. Updated diagnostic manifests and future-build/verification scripts consistently.

Inspected host state and confirmed no RAC resource/pods existed. On each worker sequentially, guarded by its scratch UUID and completely unused HugePages pool, backed up /etc/sysctl.d/98-ocne-rac.conf under /var/opt/ocne-rac-hugepages-backup-<timestamp>, increased vm.nr_hugepages from 1024 to 1536, saved that setting and restarted kubelet. Both workers remained Ready and advertised 3Gi HugePages; ordinary allocatable memory was 18877204Ki/18877232Ki. No VM reboot was performed. Persistence is configured in sysctl.d; this new value has not yet been verified across reboot.

The two diagnostic pods scheduled with 4CPU, 16Gi ordinary memory and 3Gi HugePages. Both private networks passed bidirectional 1472-byte payload pings and DNS; hugetlbfs mounts and the new shmmax were verified. Removed only the two named test pods. Separately used a temporary hugetlbfs file and mmap on each host to allocate and touch all 1536 HugePages (3 GiB), then unmapped/unlinked it and verified every page was free again. Worker checks passed for SELinux, mounts, private NICs, THP, kernel settings, services and Chrony. This is host allocation and diagnostic scheduling evidence, not a RAC runtime test.

The revised manifest passed server-side create dry-run. Windows/control-plane copies match SHA256 `8c76f48256eb145460033b2499b80a7a736d77d14fd95931200dfa4a0a7790b2`. No RacDatabase or pods remain in namespace rac. The earlier 2G dry-run/fingerprint entries are historical; 3G is now the user-selected configuration. No RAC provisioning was performed.

Final validation at 22:11 EDT passed for all three Kubernetes nodes, all current deployments and all 22 pods. Five changed/new Bash scripts and 29 documentation Bash blocks parsed; the diagnostic YAML matches its embedded script, and the 3Gi HugePages/SGA/shared-memory values are consistent. Documentation validation passed for 18 Markdown files and 132 local links.

## RAC provisioning authorized and started - 2026-10-10 22:14 EDT

The user explicitly authorized Codex to provision RAC, superseding the earlier user-only handoff boundary. Final host/node/certificate/secret and dedicated ASM identity/blank-signature checks passed. Applied the reviewed manifest with SHA256 8c76f48256eb145460033b2499b80a7a736d77d14fd95931200dfa4a0a7790b2 after another successful server dry-run. RacDatabase rac/rac19c was created at 2026-10-11T02:14:00Z, UID 6be9de9e-f884-4b82-848b-52eadd7213d1, initial state PENDING. Provisioning and runtime acceptance are in progress; creation alone is not database success. Do not rerun blank-ASM or one-time provisioning helpers after this point.

## 10 October 2026, 22:22-22:32 EDT - first GI error and credential recovery

GI configuration stopped before Clusterware creation with INS-30003: the SYS and ASMSNMP passwords exceeded the installer's 30-character maximum. The local prerequisite generator had produced 32 characters. Corrected future generation to 24 characters with uppercase, lowercase, digit and underscore. No change to the supplied gold homes or patch policy.

Verified both pods had no OCR location file and no active installer/database processes. The guarded Repair-RAC-Preinstall-Password.sh preserved a protected recovery backup on ocne-cp, generated and RSA-OAEP-encrypted the replacement, verified decryption, replaced only the encrypted password in the existing secret, and verified both pod projections. Private keys and the SSH secret were preserved; no credential was displayed.

Resumed the existing first-node runOracle.sh at 22:31:34 EDT. It reused the extracted directories and entered software/configuration checks. Pods, CR, PV/PVC resources and ASM devices were preserved. Database creation and acceptance remain pending. This is an observed failed attempt and recovery in progress, not a completed RAC deployment.

## 11 October 2026, 09:30-09:41 EDT - DBCA memory failure and HugePages disabled

Observed Clusterware, both ASM instances and DATA online on both pods. The prior DBCA attempt stopped at 02:49 UTC with ORA-27125 / ORA-01034. Its alert log reported ENOSPC, SGA_TARGET=3072 MB, expected 1537 two-MiB pages and only 1536 available. Pod shmall was exactly 3 GiB, leaving no shared-memory overhead. Database creation had not completed and no RACCDB Clusterware resource existed.

The user explicitly requested disabling HugePages. Disabled the unused pool on both workers, persisted vm.nr_hugepages=0 in /etc/sysctl.d/98-ocne-rac.conf, and verified HugePages_Total/Free/Rsvd=0 and THP=[never]. Preserved SGA3G/PGA2G and 16Gi ordinary pod memory. Updated desired CR/templates and local manifest to remove hugepages-2Mi, TOTAL_MEMORY=16384 and IPC limits shmall=2097152, shmmax=8589934592.

Direct pod sysctl writes were denied by Kubernetes' read-only procfs. Used the observed CRI container PID to enter only each pod's IPC namespace from its worker and apply those namespaced limits; verified inside both pods. This did not modify the host's IPC limits. StatefulSets use OnDelete during recovery so the template changes do not interrupt working GI. Existing pod resource fields still contain the old reservation until controlled recreation; the actual host pools are already zero. No kubelet/VM/pod restart was performed in this correction.

Resumed the image's existing first-node setup at 09:40:59 EDT, preserving homes and ASM. It rechecks existing GI/ASM before retrying DBCA. SQL acceptance remains pending.

## 11 October 2026 - RAC completion, manual and exercise prechecks

DBCA completed at10:19EDT. After correcting the image ORACLE_PDB/ORACLE_PDB_NAME mismatch, LABPDB opened READ WRITE on both instances. The original root-container labpdb service was replaced with labpdb_app mapped to LABPDB/preferred RACCDB1,RACCDB2. The CR service name is immutable; the existing live manifest retains labpdb, while the fresh-build manifest uses labpdb_app from creation. Domain-rename experiments failed to resolve reserved default-service naming (ORA-65042/PRCD-1278); these were recorded as failed workarounds, not successful reconciliation. The current PDB global name is LABPDB.lab.test; the CR still displays its old ORCLPDB connection summary.

A controlled database stop/start at10:55-10:57EDT applied explicit USE_LARGE_PAGES=FALSE. Verify-RAC-Database.sh passed at10:58: both CRS/ASM stacks, two OPEN/ACTIVE instances, DATA MOUNTED/EXTERN/zero offline disks, live19.32 inventories, RU39472050/OJVM39222882 SQL SUCCESS in root and PDB, no invalid registry components, SGA3GiB/PGA2GiB and FALSE on both. No pod/worker reboot was performed; old pod hugepage declarations and OnDelete strategies remain as documented.

At18:45UTC Capture-RAC-Manual-Evidence.sh passed TCP from ocne-cp to both worker listeners and SQL from a pod through .12:31522 and .13:31523/labpdb_app. Results were LABPDB/RACCDB1 and LABPDB/RACCDB2, with final memory/PDB/service verification. Full sanitized output is in MANUAL-04-RAC-OPERATIONS.md; raw local log is logs/ssh-ocne-cp-Capture-RAC-Manual-Evidence-20261011-144532.txt.

At the user's request, created the four-part manual: OCNE prerequisites/setup; Database Operator prerequisites/install; RAC prerequisites/provisioning with complete YAML; operations with commands/output/troubleshooting. Added an expanded28-scenario workbook, full diagnostic output pages, Mermaid/SVG diagrams and printable HTML. Manual commands are adaptations for a future build, not a claim every block was rerun on this existing cluster. Disk identity/format guards require observed values; secrets and disks remain excluded from Git.

At19:04UTC the read-only pod-replacement baseline correctly stopped with exit2: /u01/app/grid/.etcoraclebackup/oracle was absent. Subsequent actual-image source/directory inspection confirmed the missing persistent GI recovery directory on BOTH nodes, while their current /etc/oracle directories exist in container filesystems. The image restore code expects the missing persistent path. No pod was deleted or restarted. Full failed-precheck output is preserved in RAC-EXERCISE-BASELINE-OUTPUT.md. This is a recovery prerequisite gap, not a failure of the running database.

At19:05UTC read-only continuation confirmed both instances OPEN/services online, ARCHIVELOG, no active user transactions at that observation and no RMAN backup jobs in v$rman_backup_job_details. No Warning events were present in rac. These observations do not establish a backup or authorize an unannounced workload outage. Asked whether a maintenance window is available; no answer received during this documentation work. Disruptive/failure/restore exercises remain unexecuted and are labeled so. No disk/network fault, container crash, worker outage or full post-RAC power cycle was injected.

## 11?12 October 2026 - controlled RAC exercises and final manual

The user authorized the maintenance exercises. At23:38UTC11October, preserved each node's own /etc/oracle on persistent /u01 and verified the OCR/OLR pointers. RMAN backup database plus archivelog, controlfile and SPFILE completed with exit0; RESTORE DATABASE VALIDATE read the database pieces successfully. This is not an actual restore; pieces reside on worker1 scratch, not independent off-host storage.

Both instance stop/start tests passed survivor network SQL and recovered. The first stop failed CRS-2974 until its dependent labpdb_app service was stopped; a later redundant service start returned already-running because automatic service policy had restored it. Service-only stop/start and cordon/uncordon of both workers passed. TCP readiness stayed true during DB/service outages.

Pod2 normal deletion at23:47:54UTC created UID e5fb5f48-cfcc-4476-97d9-07338262095d /10.244.2.10. Its GI restore failed because cp -a had preserved the old container MCS category. Targeted restorecon on both worker-side backup trees restored existing container_file_t:s0 policy, retaining SELinux Enforcing. Verified empty node2 /etc/oracle was restored with cp -rp; rootcrs.sh -updateosfiles, orainstRoot.sh and start-CRS recovered GI. Ready preceded SQL; full acceptance passed after ASM/database opened. This was assisted recovery, not unattended success.

Pod1 normal deletion at23:56:58UTC created UID590e8b8f-3a93-43d1-a8ea-3549e6b83201 /10.244.1.11. With backup labels fixed, image startup restored GI automatically, then incorrectly started CRS twice. The second call returned CRS-4640/CRS-4000 and caused a redundant installation attempt rejected by INS-40401. No deinstall/recreation was used. Existing database recovered; both SQL paths passed00:02UTC12October. The duplicate-start logic defect remains in the supplied image. Both replacement pods now declare4CPU/16Gi ordinary memory, no HugePages request.

Database Operator rollout restart at00:03UTC completed; RAC UIDs stayed unchanged and both SQL paths passed. Full CRS/ASM/patch/SQL/memory acceptance at00:04UTC passed. Next-morning capture at11:44UTC12October reconfirmed Ready nodes/pods, OPEN/ACTIVE instances, LABPDB READ WRITE, SGA3GiB/PGA2GiB, USE_LARGE_PAGES=FALSE and both network SQL paths. CR transient Pending fields refreshed to OPEN/PRIMARY/19.32; legacy ORCLPDB connection summary remains stale.

Completed the four-part beginner manual, diagrams, full sanitized transcripts,28-scenario workbook and command/expected/actual results table. Actual restore/PITR, disk/network failure, deliberate container crash, worker reboot and full post-RAC VM cycle remain unexecuted. Their diagnosis/recovery boundaries are documented; heavier restart tests await image startup correction/retest. No credentials, raw private logs, binaries or disks are included in tracked documentation. See RAC-TEST-SCENARIO-MATRIX.md and RAC-EXERCISE-*-OUTPUT.md for evidence.

Documentation validation on12October: all124 Bash scripts, embedded Python,156 manual Bash blocks,14 PowerShell scripts and23 PowerShell manual blocks parsed successfully; three current YAML manifests parsed. Renderer verified31 Markdown files/297 local links, anchors, fenced-code preservation and14 generated HTML copies. Visually reviewed the scenario table in Edge:28 rows, no horizontal overflow at1600px. git diff --check passed; repository secret-pattern review found no credential payloads. These static checks do not constitute a fresh lab rebuild.


## 12 October 2026 - RAC Lab Board local development (not deployed)

At the user's request, developed a small frontend and three services under apps/rac-lab-board, separated into frontend, backend/node-gateway, backend/python-tasks, backend/java-notes, database, kubernetes, scripts, tests and docs. The frontend displays tasks/notes and service/pod/database-instance metadata; Node routes requests; Python and Java contain separate Oracle Thin adapters. UUID primary keys and identical-payload retries handle unknown write outcomes without duplicating a committed record. Memory mode is explicit and local only.

Read host/configuration/source documentation and inspected Windows storage/tooling and the existing cluster without mutations. Observed the existing two listener Services (31522/31523), labpdb_app connection target, worker labels and resource reservations; selected unused NodePort30080 for future frontend access. Proposed eight application pods request650m CPU/1GiB memory total. Worker memory remains22GiB each. Existing RAC image startup defects and the below-minimum operator/control-plane choices remain documented limitations.

Downloaded a checksum-verified portable JDK under private/app-tools and prepared ignored Python/Java development dependencies on D:. Docker's Linux engine was stopped and was left stopped. No container images were built or staged, no database credentials/users/tables were created, no Kubernetes resources were applied, and no RAC/VM failure was injected. No GitHub push was performed.

Final local acceptance at23:30:48-23:31:14UTC passed15 HTTP tests,5 Python fake-driver transaction tests and1 real-driver closed-loopback test with both Python/Java subtests. Browser acceptance passed lost-response retry across reload, deduplication, mobile layout and escaped markup. Local workload probes each created/verified5 records with no missing/unknown IDs. Kubeconform validated14 resources against Kubernetes1.29.14:14 valid, no errors/skips. Local demonstration processes were stopped. These results do not establish live Oracle integration, image builds, cluster scheduling or RAC failover.

Saved the detailed architecture/sequence diagrams, screenshot, per-folder READMEs, PowerShell/Bash walkthrough,20-scenario future failover workbook, expected-vs-actual validation table and sanitized full output. See apps/rac-lab-board/docs/VALIDATION.md and TEST-OUTPUT.md. Development findings/fixes are recorded there. Full cluster and Oracle acceptance is intentionally future work, as the user explicitly requested no deployment.

The user subsequently authorized publication of the application to the existing roopla/ocne-lab-codex GitHub repository. Pre-push review confirmed59 new source/documentation assets, no runtime binaries or credential payloads in the selected files,42 valid application documentation links and298 existing lab links. Application deployment and live Oracle acceptance remain unexecuted.
