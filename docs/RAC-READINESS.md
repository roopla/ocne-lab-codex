# RAC readiness and media inventory

Status on 10 October 2026: host/cluster prerequisites are configured and the gold-home manifest passed server-side dry-run. RAC is not provisioned. CVU container-host validation passed on both workers. User-supplied slim image and patched home ZIPs and their acceptance checks remain outstanding. See the [manual Bash guide](RAC-PREREQUISITES-GUIDE.md), [user handoff](RAC-PROVISIONING-HANDOFF.md), and [cloning run log](CLONING-RUN-LOG.md).

## Verified installation media

The files are under `D:\OCNE19-Lab\ISO`. Archive members were inspected without executing or extracting installers. All five ZIP archives passed full CRC checks on 9 October. SHA256 values are local fingerprints, not a completed comparison with Oracle-published checksums.

| File | Identified content | SHA256 |
|---|---|---|
| LINUX.X64_193000_db_home.zip | Database 19c base media | ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8 |
| LINUX.X64_193000_grid_home.zip | Grid Infrastructure 19c base media | d668002664d9399cf61eb03c0d1e3687121fc890b1ddd50b35dcbe13c5307d2e |
| p39467003_190000_Linux-x86-64.zip | GI RU 19.32.0.0.260721 | 5eba8519ac16e7eb2701f977b5f81f0e7f49225da1f430966bdc8fed9e649198 |
| p39472050_190000_Linux-x86-64.zip | Database RU 19.32.0.0.260721 | 9cef81dc1de61635ec8680480b49db2334c35322f106189c1eb32f62cadc4350 |
| p6880880_190000_Linux-x86-64.zip | OPatch 12.2.0.1.53 | ad67904c8c148ca1fcde5d0bb6f572a381e662c7d22735cffc5916ad2e330b2b |

Both local RU README.html files require OPatch 12.2.0.1.52 or later. The downloaded OPatch version satisfies that requirement. The GI RU includes Database RU 39472050; the separate DB RU archive is not an additional, different database update.

Oracle's RAC example describes release-specific one-offs for 19.28. The local 19.32 OCW inventory lists fixes 37531398 and 37805442, the components of example merge 38336965. The DB RU inventory does not list 34436514. This metadata check does not determine whether a separate 19.32-compatible DBCA fix is needed. Resolve applicability and conflicts before patch execution; never install a 19.28 one-off blindly on 19.32.

Reproduce local archive checks with [Inspect-RAC-Media.py](../scripts/Inspect-RAC-Media.py). It writes `logs/rac-media-inventory.json`; it neither extracts nor executes archive contents. Full checks read all downloaded ZIP data and may take several minutes.

## Foundation recovery gate

The 1 October acceptance is historical. The 9 October preflight found worker 2 NotReady, reset SSH connections and console kernel soft lockups/RCU stalls. Other guests had substantial clock drift and watchdog failures. Diagnostics were saved before recovery. A running VM or stale Running pod status is insufficient proof of health.

Before adding components, verify all guest clocks against selected NTP sources, stable SSH, three Ready nodes, current ready pods/deployments, storage UUIDs/mounts, NFS access and SELinux Enforcing. Retain diagnostics if faults recur. Later Windows Kernel-Power 506/507 events established Modern Standby intervals matching guest clock jumps and VirtualBox timer lag. AC sleep was changed from 60 minutes to never; prior settings are saved in logs/power-before-rac-20261009.txt. Fresh time, Kubernetes and NFS checks passed after resume. Full-boot diagnostic checks still report the preserved historical standby warnings; bounded post-mitigation checks showed no new warnings. Long-term stability remains to be observed.

The operator has an additional bridged NIC with observed DHCP address 192.168.137.229. Preserve it and keep 192.168.77.10 as the documented lab/NFS address. The extra address is not a static allocation or an established RAC interconnect.

## Installed versions and remaining artifact gates

Oracle Database Operator tag `2.2.0` resolves to commit `ff6f9178c1650df30afbf203ebdb633e9b80760a`. A review checkout is under ignored `private/oracle-database-operator-2.2.0`. The operator was subsequently installed with one lab replica, watch namespaces rac and oracle-database-operator-system, and pinned amd64 digest sha256:f378d66fd0b47b6089f01caf4ca86f90f3b3593cdca75292ff6491955c451cc0. Controller readiness, certificates and admission dry-run passed.

The cluster runs Kubernetes 1.29.14+2.el9. Cert-manager 1.17 lists Kubernetes 1.29 compatibility, but its community maintenance ended 7 October 2025. The latest observed patch tag is v1.17.4. Currently maintained 1.20/1.21 releases exclude Kubernetes 1.29. Any choice for this fixed OCNE 1.9 lab must record that lifecycle limitation; do not apply the operator README's current cert-manager example without checking compatibility. See the [cert-manager release matrix](https://cert-manager.io/docs/releases/).

Worker preparation now includes shared ASM partitions, isolated Multus networks, 128 GiB scratch filesystems, kernel settings, Oracle's SELinux policy and 2 GiB HugePages per worker. Worker RAM remains 22 GiB each. Final pod resources are 16 GiB ordinary memory plus 2 GiB HugePages and 4 CPUs; the operator enforces the 16 GiB ordinary-memory minimum. This is a constrained lab configuration, not RAC capacity validation. Original NFS/container disks retain their existing roles. CVU 23.26.3.0.0 subsequently passed the Kubernetes container-host check on each worker; [results](RAC-CVU-RESULTS.md).

Windows/VirtualBox shared-disk and NIC orchestration is local implementation. Identify every new disk by its VM attachment, UUID, serial, signatures and mounts before initialization. Do not assume a device letter. Shared ASM requires shared block storage; the existing NFS share is not an ASM block device.

No RAC credentials, registry credentials, private keys or kubeconfigs belong in this document or Git. Stage protected material under `private/` on Windows or restricted guest paths, and suppress secret output.

## Sources

- [Oracle Database Operator 2.2.0 source](https://github.com/oracle/oracle-database-operator/tree/ff6f9178c1650df30afbf203ebdb633e9b80760a)
- [Pinned RAC controller prerequisites](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/prerequisites_oracle_rac_db.md)
- [Oracle RAC installation on OCNE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rackb/install-configure-rac-olcne.html)
- [Oracle Linux Chrony configuration](https://docs.oracle.com/en/learn/ol-chrony/)
- [Chrony tracking, makestep and waitsync reference](https://chrony-project.org/doc/4.6.1/chronyc.html)

Patch-specific version requirements above come from the locally downloaded Oracle patch readmes. Restricted support content is not republished here.

## Current RAC storage and networks

| Asset | Identity / allocation | Verified state |
|---|---|---|
| Worker1 scratch | VDI 323d540b-a613-4c07-9f3a-b71b5532128e; XFS 48e2e0e8-d37d-4262-a2d3-67b40eacf76b | 128 GiB, mounted /scratch |
| Worker2 scratch | VDI a7088f24-b59a-4401-89d0-2cf508b57b01; XFS 8d744a6a-39bf-4cb4-9ab3-739dbff7c319 | 128 GiB, mounted /scratch |
| Shared ASM01 | VDI db34f551-0ee8-4aca-a1aa-cde35a0f7d50; PARTUUID c25151a5-4557-444f-916f-cc359f3fd43b | 50 GiB fixed/shareable, GPT partition, no filesystem |
| Shared ASM02 | VDI c280454f-b4c7-4b30-be79-e7cabc280f7e; PARTUUID 14cb5bdb-e6ff-4706-b82f-b0f748df5157 | 50 GiB fixed/shareable, GPT partition, no filesystem |
| Private1 | ocne-rac-priv1 / enp0s8 / macvlan-conf1 | 192.168.78.0/24, unnumbered parent, MTU 1500 |
| Private2 | ocne-rac-priv2 / enp0s9 / macvlan-conf2 | 192.168.79.0/24, unnumbered parent, MTU 1500 |

Network tests passed in both directions on both private networks, plus Kubernetes DNS. The guest NICs require persistent promiscuous reception in addition to VirtualBox allow-vms policy. Latest full acceptance and reboot results are chronological in the run log.

Cert-manager v1.17.4 is installed; its three deployments and the Database Operator were Ready. Required secrets and worker labels exist. No RacDatabase/PV/PVC has been created for the database. The previous verified base/RU media are preserved but will not be used by the user's gold-home workflow. Empty gold-home stage directories are prepared on both workers.
