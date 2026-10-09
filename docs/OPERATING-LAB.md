# Operating the completed lab

Project: `D:\OCNE19-Lab`. Last live acceptance: **2026-10-01 22:08 EDT**, followed by the OCNE report at 22:10. Documentation review: 2026-10-08. Run the checks below when returning; recorded success is not a live health assertion.

## Access and topology

From Windows, use `ssh ocne-op`, `ssh ocne-cp`, `ssh ocne-w1` or `ssh ocne-w2`. Each connects as `labadmin`; sudo still requires the account password. See [SSH access](SSH-ACCESS.md).

| Node | Address | RAM / vCPU | Role |
|---|---|---|---|
| ocne-op.lab.test | 192.168.77.10 | 4 GiB / 2 | Platform API/CLI, separate NFS server |
| ocne-cp.lab.test | 192.168.77.11 | 8 GiB / 4 | Single Kubernetes control plane |
| ocne-w1.lab.test | 192.168.77.12 | 22 GiB / 6 | Worker |
| ocne-w2.lab.test | 192.168.77.13 | 22 GiB / 6 | Worker |

The golden VM remains powered off. Guest traffic uses `ocne19-net`; guest DNS was verified at `192.168.137.1` during setup. If the Windows LAN changes, inspect DNS reachability and NetworkManager before changing addresses.

## Inspect before starting

Run in Windows PowerShell:

```powershell
Set-Location D:\OCNE19-Lab
.\scripts\00-Inspect-Host.ps1
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
& $VBox list runningvms
foreach ($node in 'ocne-op','ocne-cp','ocne-w1','ocne-w2') {
    & $VBox showvminfo $node --machinereadable |
        Select-String '^(name|VMState|memory|cpus)='
}
Get-CimInstance Win32_OperatingSystem |
    Select-Object @{n='FreeRAMGiB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
Get-Volume -DriveLetter D |
    Select-Object DriveLetter,@{n='FreeGiB';e={[math]::Round($_.SizeRemaining/1GB,1)}}
```

Script 00 is read-only. Its final “8 GiB remaining” message assumes a nominal 64 GiB host; this host actually reported 61.66 GiB visible RAM, so nominal headroom against 56 GiB of guest allocations is about 5.66 GiB. Use current memory/storage output when deciding whether to start the lab.

## Start in order

Execute start commands only for VMs observed Powered Off. If a VM is running, verify it; if Saved or in an unexpected state, inspect before proceeding.

Start the operator from Windows:

```powershell
& $VBox startvm ocne-op --type headless
```

Wait for SSH, then log in with `ssh ocne-op`. On the operator:

```bash
findmnt -M /srv/nfs
df -hT /srv/nfs
systemctl is-active nfs-server olcne-api-server
sudo exportfs -v
```

Confirm `/srv/nfs` is the expected XFS filesystem (UUID below), and `/srv/nfs/share` is exported to the four lab addresses. The NFS service has a mount dependency on this filesystem. Do not start clients against an unmounted/incorrect export.

Back in Windows, start the control plane, then workers:

```powershell
& $VBox startvm ocne-cp --type headless
& $VBox startvm ocne-w1 --type headless
& $VBox startvm ocne-w2 --type headless
```

Verify client mounts and Kubernetes readiness below. Startup may take several minutes; inspect events/logs if progress stops.

## Routine health checks

From Windows:

```powershell
foreach ($node in 'ocne-op','ocne-cp','ocne-w1','ocne-w2') {
    ssh -n -o BatchMode=yes $node 'hostname; uname -r; getenforce; systemctl --failed --no-pager'
    if ($LASTEXITCODE -ne 0) { throw "SSH/check failed on $node" }
}
ssh ocne-cp kubectl get nodes -o wide
ssh ocne-cp kubectl get deployments --all-namespaces
ssh ocne-cp kubectl get pods --all-namespaces -o wide
```

Inspect returned failures: listing failed systemd units alone does not assert that the list is empty. Expect three Ready nodes; every intended deployment must have its replicas available/updated, and each current base-lab pod must have Ready=True. At acceptance there were 15 pods and four deployments; these are recorded counts, not a requirement after adding workloads.

For the existing base-lab assertion helper:

```powershell
.\scripts\Invoke-LabSSH.ps1 -Node ocne-cp -CredentialName labadmin -ScriptPath D:\OCNE19-Lab\scripts\Verify-Kubernetes-Ready.sh
.\scripts\Invoke-LabSSH.ps1 -Node ocne-op -CredentialName labadmin -ScriptPath D:\OCNE19-Lab\scripts\Report-OCNE-Cluster.sh
```

The SSH helper writes local logs and uses existing protected credentials. It syntax-checks guest scripts before execution. The readiness helper assumes exactly three nodes and only Running/Ready pods; future completed Jobs or a changed topology need a reviewed check. A healthy OCNE report alone is insufficient: see the [known report discrepancy](TROUBLESHOOTING.md).

On the control plane and each worker, log in and run:

```bash
findmnt -M /mnt/ocne-share
systemctl is-active olcne-agent crio kubelet
swapon --show
```

The client mount must reference `192.168.77.10:/srv/nfs/share` with NFSv4.1, rw, hard and nosuid. Kubernetes-node swap should be empty. On each worker also check:

```bash
findmnt -M /var/lib/containers
df -hT / /var/lib/containers /mnt/ocne-share
```

Read existing acceptance files as labadmin on each client with `cat /mnt/ocne-share/nfs-check-*.txt`; use `/srv/nfs/share/` on the operator. To repeat actual write testing deliberately, use `Write-NFS-Acceptance.sh` as labadmin on all four, then `Verify-NFS-Acceptance.sh` as labadmin on all four. The write helper replaces only that node's named acceptance file. See [Script reference](SCRIPT-REFERENCE.md) for invocation and contexts.

## Stop in order

This procedure applies to the base lab. Before adding database workloads, extend it with their application shutdown procedure.

1. In separate SSH sessions to both workers and the control plane, run `sudo shutdown -h now`. The disconnect is expected.
2. On Windows, check `showvminfo --machinereadable` for all three clients. Wait until each reports `VMState="poweroff"`.
3. Only then log into the operator and run `sudo shutdown -h now`.
4. Verify all four VMs are Powered Off before shutting down Windows.

Do not use VirtualBox forced poweroff as the normal shutdown mechanism. The historical `Shutdown-Lab-Guest.sh` helper schedules shutdown one minute later, so a successful helper exit is not proof that a VM is off.

## Storage inventory

All clone disks live under `D:\OCNE19-Lab\vms`. Every node has a separate 100 GiB boot disk; `/var` shares its approximately 99 GiB root XFS filesystem. Root filesystem UUIDs were inherited by independent full clones; machine IDs and SSH identities were changed. A root filesystem UUID alone does not identify a particular VM.

| Owner / mount | Separate capacity | Filesystem UUID |
|---|---:|---|
| ocne-op /srv/nfs | 100 GiB | ec04e2ec-926d-4e48-bca1-dc23e972f34b |
| ocne-w1 /var/lib/containers | 100 GiB | 1ca6c397-b848-4e95-a24a-a96ea11a55cc |
| ocne-w2 /var/lib/containers | 100 GiB | 50e55c0d-a63c-41c4-b66c-7a46cae288ab |

NFS share `/srv/nfs/share` is owned by UID/GID 1001, mode 0770. The same 100 GiB capacity is shared by all clients. Exports retain root squashing; SELinux remains Enforcing. Independent worker container disks are not shared database/ASM disks.

If a mount is missing, inspect the existing attachment, UUID, fstab and logs. Do not run a formatting helper or recreate a VDI to repair a missing mount.

## Certificates, credentials and backups

- Windows key, pinned known_hosts and DPAPI-encrypted transport credentials: ACL-restricted `private/`.
- Each guest's labadmin private SSH key: `/home/labadmin/.ssh/id_rsa`; only public keys were exchanged.
- OCNE CA and generated node material on the operator: `/home/labadmin/certificates/`.
- CLI certificate directory: `/home/labadmin/.olcne/certificates/ocne-op.lab.test:8091/`.
- Installed platform certificates: `/etc/olcne/certificates/` on each VM.
- ExternalIPs certificates on the operator: `/home/labadmin/certificates/restrict_external_ip/`.
- Kubernetes administrator kubeconfig: `/home/labadmin/.kube/config` on the control plane, mode 0600.

Inspect public certificate validity with `openssl x509 -in /etc/olcne/certificates/node.cert -noout -subject -dates` on each guest (use sudo if needed). Certificates require lifecycle management; expiry/renewal is not automated by this package. See [certificate recovery](CERTIFICATE-DISTRIBUTION.md) and the cited Oracle procedure before changing PKI.

VM disks, NFS data and credentials are not backed up by Git. DPAPI-protected files are tied to the Windows user's protection context; copying the folder alone is not a tested recovery method. Keep sensitive backups protected and outside tracked files. No backup/restore exercise was performed.

## Scope and limits

The last acceptance verified OCNE/Kubernetes, mounts, all-node NFS reads/writes, root squashing, enforcing SELinux and Windows SSH after restart. Operator/control-plane RAM remains below Oracle minimums. All VMs share one Windows host and one control plane.

No new VM execution was performed for the October documentation revision. Database Operator, Multus, shared ASM disks, database/RAC workloads and Kubernetes storage provisioning remain outside the completed baseline. Their preparation stays paused.
