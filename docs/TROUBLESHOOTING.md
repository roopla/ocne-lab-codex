# Observed OCNE lab issues and resolutions

These findings describe the September/October 2026 build, not a new live diagnosis. Detailed chronology and final acceptance are in [CLONING-RUN-LOG.md](CLONING-RUN-LOG.md). Resume from current evidence; do not rebuild a completed resource to fix a naming conflict.

| Observation | Resolution / next check | Recorded outcome |
|---|---|---|
| Source boot disk was only 40 GiB; /var shared its root | Expanded independent clone VDIs to 100 GiB, then guarded growpart and xfs_growfs; verified unchanged partition start/root UUID | All clones had ~99 GiB root; source remained unchanged |
| Golden VM used a normal snapshot chain and a global Downloads share | Inspected every parent; full current-state clones flattened the chain; explicitly reviewed global share while preserving unrelated resources | Independent clone disks; no guest vboxsf mount |
| Identity script rejected the clone's SMBIOS UUID | Compared actual VBox UUID, SMBIOS byte order and MAC; accepted the two verified UUID representations | Unique identities verified on all clones |
| Worker container directory was not literally empty | Confirmed only known empty Podman scaffolding; backed it up and restored metadata on the separately identified XFS disk | Dedicated mounts persisted after reboot; no existing container data discarded |
| Documented repository package resolved to a different release-package name | Inspected installed package and enabled repo IDs | oracle-ocne-release-el9 1.0-7 supplied ol9_olcne19; platform 1.9.6 installed |
| labadmin certificate distribution failed on noninteractive sudo | Preserved generated PKI; used documented copy with temporary restricted root access; verified results and removed access | Platform certificates/services verified; see certificate recovery |
| Certificate copy transport did not exit | Verified copied files and running services; inspected and terminated only identified stalled transports | Recovery completed; normal copy exit success was not claimed |
| OpenSSH rejected Windows configuration permissions | Restricted the included config's ACL to the Windows user and SYSTEM | Four pinned workstation key logins verified |
| Windows hosts resolved guest IPs but NAT subnet had no direct host route | Used per-node SSH aliases overriding HostName to 127.0.0.1 and ports 2220–2223 | Name resolution and SSH routing documented separately |
| Flannel image pull appeared slow; worker2 initially restarted twice | Checked events/logs and transfer progress; waited for networking dependencies | All nodes and pods became Ready without reinstalling |
| NFS helper mounted an already-mounted share again and got access denied | Removed the redundant second mount; checked existing source/options/fstab | All-node labadmin reads/writes and reboot persistence passed |
| Deployment counters appeared ready before all restarted pods were Ready | Added live pod Ready-condition checks to acceptance | Three nodes, 15 pods and all four deployments verified at 22:08 |
| OCNE report detail showed kernel 4.12.0 and closed firewall ports despite healthy status | Compared direct uname, runtime/permanent firewalld, packaged firewall check and real workload readiness | **Cause unresolved**; inconsistent report fields were not used as the acceptance source |

## OCNE report discrepancy

The 22:10 report returned successfully and showed healthy homelab/cluster1. Its kernel/firewall detail fields contradicted direct state: all guests ran the recorded UEK R7 5.15 kernel; checked worker2 ports were open in runtime/permanent firewalld, and Oracle's packaged firewall check also passed.

For a recurrence, inspect the relevant guest directly:

```bash
uname -r
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --query-port=10250/tcp
sudo firewall-cmd --permanent --zone=public --query-port=10250/tcp
sudo nft list chain inet firewalld filter_FORWARD_POLICIES_post
```

The observed lab interface used the public zone; recheck the active zone first. Inspect the actual affected port, service and node, not only this example. Cross-check kubectl node/pod conditions. Do not change kernels or open additional ports merely to make a report field look correct. No upstream cause or fix was established in this run.

## Forwarding service behavior

Oracle's OL9 forwarding example uses Restart=always and RestartSec=10. It was observed successfully applying the rule and automatically restarting; that behavior alone was not a failure. Check unit Result/exit status and the actual accept rule, including after firewalld restart or guest reboot. Retain the documented configuration unless evidence and the source justify a change. See installation guide B5.

## Missing mounts and NFS permissions

Check existing VBox attachments, device serial/UUID, filesystem signatures, fstab and findmnt before any repair. Equal disk capacities do not establish identity. Do not rerun mkfs or create replacement VDIs for an existing filesystem.

For NFS, verify the operator's /srv/nfs filesystem is mounted before examining exports. Compare numeric labadmin UID/GID 1001, ownership/mode, idmap domain lab.test, source/options and server/client services. Root writes being denied is expected with root squashing and mode 0770; labadmin writes must succeed. Investigate actual SELinux denials rather than disabling enforcement or changing the export to no_root_squash.

## Resource and verification limits

No OOM/resource failure was observed during final base-lab checks. Operator 4 GiB and control plane 8 GiB remain below Oracle's documented minimums. Worker memory remains 22 GiB each. These checks did not validate database workload capacity, backup restoration, certificate renewal or high availability.

Original Oracle sources remain in the [installation guide](OCNE-1.9-OL9-Setup-Guide.md) and [cloning guide](OCNE-1.9-Golden-VM-Cloning-Guide.md). Local fixes are identified there. The [operating runbook](OPERATING-LAB.md) is the entry point for returning to this completed lab.
