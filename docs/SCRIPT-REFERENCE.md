# Script reference and execution boundaries

This is a map of the existing implementation, not a run-all script list. Read the actual file and current state before executing it. Linux commands run through SSH; one-time preparation used disconnected VM consoles. Runtime disk/credential identifiers embedded in helpers apply only to the recorded run.

## Windows orchestration

| Helper | Context and effect |
|---|---|
| 00-Inspect-Host.ps1 | Read-only host, disk, VM, network and route inspection; its nominal 64 GiB headroom message must be compared with actual host RAM |
| 01-Create-Network.ps1 | One-time NAT network creation; inspect existing network first |
| 02-Create-VMs.ps1 / 03-Boot-Installed-VMs.ps1 | Fresh ISO workflow only; **not used or permitted for these clones** |
| 04-Apply-RAM.ps1 | VM configuration change, powered off; no need to run on the completed lab |
| 05-Add-NFS-Disk.ps1 | One-time blank operator disk attachment, operator powered off |
| 06-Clone-Golden-VM.ps1 | Preflight by default; -Create makes full clones; explicit BootDiskMB and ReviewedGlobalShare options used for this source |
| 07-Add-Worker-Container-Disk.ps1 | One-time blank worker disk attachment, target powered off |
| Common.ps1 | Shared project/config/VBox functions, dot-sourced by orchestration |
| Invoke-LabConsole.ps1 / Build-Clone-Prep-ISO.py | Historical disconnected identity preparation; not an unattended OS installer |
| Invoke-LabSSH.ps1 | Reads protected local credentials/pins, syntax-checks and executes a guest script, writes logs and removes temporary transport files |
| Set-Labadmin-Credential.ps1 | Credential/account mutation; do not use as a health check |
| Update-Windows-Lab-Hosts.ps1 | Administrator-level hosts-file update; inspect/backup entries and preserve unrelated mappings |
| Render-Documentation.py | Documentation only: generate guide HTML, or --check without writing |

## Routine verification candidates

Use the indicated credential with Invoke-LabSSH.ps1. “Root” means the helper's existing **golden credential profile**, not that the command should target the golden VM. The profile name is historical; its credentials were inherited by clones. Never pass -Node ol9-golden for clone operations.

| Guest script | Target | Credential / effect |
|---|---|---|
| Verify-Kubernetes-Ready.sh | ocne-cp | labadmin; checks three nodes, deployment replicas, all pods Running/Ready |
| Wait-Kubernetes-Pods.sh | ocne-cp | labadmin; waits for pod readiness, does not install resources |
| Report-OCNE-Cluster.sh | ocne-op | labadmin; obtains module report |
| Verify-Final-Guest-State.sh | Each clone | root; kernel, identity, services, firewall, swap/mount inspection; inspect failed-unit output as well as exit status |
| Verify-NFS-Server.sh | ocne-op | root; mounted XFS, export/service/domain checks |
| Verify-NFS-Client.sh | cp, w1, w2 | root; source, NFS version, domain and SELinux checks |
| Verify-NFS-Acceptance.sh | Each clone | labadmin; reads four acceptance files and checks numeric ownership |
| Write-NFS-Acceptance.sh | Each clone | labadmin; **writes/replaces its named acceptance file** |
| Verify-NFS-Root-Squash.sh | cp, w1, w2 | root; attempts a write that should fail; investigate if it succeeds |
| Verify-Mesh-SSH.sh | Each clone | labadmin; verifies SSH and may update known_hosts aliases from checked pins |

Example read/check invocation from Windows:

```powershell
Set-Location D:\OCNE19-Lab
.\scripts\Invoke-LabSSH.ps1 -Node ocne-cp -CredentialName labadmin -ScriptPath D:\OCNE19-Lab\scripts\Verify-Kubernetes-Ready.sh
.\scripts\Invoke-LabSSH.ps1 -Node ocne-op -CredentialName golden -ScriptPath D:\OCNE19-Lab\scripts\Verify-NFS-Server.sh
```

Do not interpret every script beginning Inspect- or Verify- as nonmutating. Inspect-Certificate-Transports.sh can terminate processes. Verify-Mesh-SSH.sh can change known_hosts; root-squash testing attempts a write.

## One-time build helpers

These helpers implement the build recorded in the guides/logs; they are not routine repair actions.

| Phase | Helpers / constraints |
|---|---|
| Identity | Prepare-Clone-Identity.sh embeds inspected UUID/MAC mappings and rejects an already-prepared clone; never rerun a reset on installed nodes |
| Boot growth | Grow-Clone-Root.sh guards the source-derived XFS UUID, partition number/start/size and 100 GiB parent; local provisioning, not a generic disk expansion utility |
| Worker/NFS formatting | Prepare-Worker-XFS.sh / Prepare-NFS-XFS.sh embed inspected disk serials and blank-device guards; formatting is one-time |
| Repositories/prerequisites | Configure-OCNE-Repos.sh / Configure-OCNE-Host-Prereqs.sh change guest package/network/service settings |
| Platform | Install-OCNE-Platform.sh / Bootstrap-OCNE-Platform.sh install/start platform components |
| PKI | Distribute-OCNE-Certificates.sh / Generate-OCNE-Service-Certificates.sh / Copy-OCNE-Certificates.sh create/copy sensitive guest material |
| Temporary certificate access | Authorize-Certificate-Copy.sh / Remove-Certificate-Copy-Key.sh contain the recorded public key; see certificate recovery |
| Environment/cluster | Create-OCNE-Environment.sh / Create-OCNE-Kubernetes-Module.sh / Validate-OCNE-Kubernetes.sh / Install-OCNE-Kubernetes.sh implement the original Oracle sequence; resume only a known incomplete stage |
| kubectl | Configure-Lab-Kubectl.sh installs protected guest kubeconfig; not a Windows copy |
| SSH mesh | Prepare-Node-SSH.sh / Prepare-Operator-SSH.sh / Authorize-Lab-SSH.sh / Authorize-Operator-SSH.sh create or authorize keys |
| NFS setup | Configure-NFS-Identity.sh / Configure-NFS-Server.sh / Configure-NFS-Client.sh alter domain/export/firewall/fstab/mount state |
| Power operations | Shutdown-Lab-Guest.sh / Reboot-Lab-Guest.sh schedule power actions; verify actual VBox state and boot IDs afterward |

Other Inspect-* helpers capture specific diagnostic data; some reference historical operation IDs or process state. Read them first. **Stop-Stalled-Certificate-Copy.sh and Inspect-Certificate-Transports.sh are historical incident scripts with process IDs and termination behavior; do not run them as routine checks.**

## Validation and credentials

Before executing a PowerShell helper, parse it without running it:

```powershell
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    'D:\OCNE19-Lab\scripts\Invoke-LabSSH.ps1',
    [ref]$tokens, [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
```

The SSH wrapper runs bash -n before the guest payload. Parsing establishes syntax only, not that mutation is appropriate for current state. Review devices, mounts, identities and intended effects separately.

The wrapper depends on PuTTY plink, private/ssh-endpoints.json, the selected DPAPI credential file, and access to private/ and logs/. Temporary credentials are removed in its finally block; inspect for remnants if execution is interrupted. Do not print credential-file contents or put passwords in command arguments/chat. Interactive sudo remains available through normal SSH sessions.

The all-pods-ready check is scoped to the original base lab and will need review when workloads introduce completed Jobs or topology changes. Source procedure and observed acceptance are in the guides and run logs.
