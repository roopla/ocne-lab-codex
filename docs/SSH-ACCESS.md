# Access from Windows and between lab VMs

Recorded verification: 1 October 2026. Documentation reviewed: 8 October. These are the installed settings, not a fresh connectivity test. Return to [Operating the lab](OPERATING-LAB.md) for startup and health checks.

Windows hosts maps ocne-op(.lab.test), ocne-cp(.lab.test), ocne-w1(.lab.test), and ocne-w2(.lab.test) to 192.168.77.10, .11, .12, and .13. Older .lab.local full names and ocne-cp1 were preserved. The previous hosts file is backed up under logs/.

From Windows PowerShell:

```powershell
ssh ocne-op
ssh ocne-cp
ssh ocne-w1
ssh ocne-w2
```

These aliases log in as labadmin using the dedicated private/workstation_ed25519 key. The Windows user's .ssh/config includes config/windows-ssh.conf. The included file uses verified loopback forwards 2220-2223 and pinned host keys, because the NAT guest subnet is not directly reachable from Windows. Hosts entries provide name resolution; they do not create a route or forward other services. Fully qualified .lab.test SSH names work too.

From any clone, logged in as labadmin:

```bash
ssh ocne-op.lab.test
ssh ocne-cp.lab.test
ssh ocne-w1.lab.test
ssh ocne-w2.lab.test
```

Each guest has its own RSA private key in /home/labadmin/.ssh/id_rsa. Only public keys were distributed. All four workstation logins and all sixteen guest-to-guest/self combinations were checked using BatchMode and verified host keys. Sudo still requires the account password. Host-side keys and encrypted credentials remain under ACL-restricted private/ and are excluded from Git.

This is local Windows/SSH orchestration, separate from the Oracle OCNE procedure. Do not change a host key pin without verifying the new key through the VM console.
## Address and transport mapping

| SSH name (short or .lab.test) | Windows hosts address | Actual Windows SSH endpoint |
|---|---|---|
| ocne-op | 192.168.77.10 | 127.0.0.1:2220 |
| ocne-cp | 192.168.77.11 | 127.0.0.1:2221 |
| ocne-w1 | 192.168.77.12 | 127.0.0.1:2222 |
| ocne-w2 | 192.168.77.13 | 127.0.0.1:2223 |

The Windows hosts file is `C:\Windows\System32\drivers\etc\hosts`. The user's `.ssh/config` includes `D:/OCNE19-Lab/config/windows-ssh.conf`. Each alias selects User labadmin, the dedicated workstation key, IdentitiesOnly=yes, HostKeyAlias set to the FQDN, private/windows_known_hosts and StrictHostKeyChecking=yes. Keep these values together.

On guests, the same names resolve directly to 192.168.77.10–13; guest-to-guest SSH does not use the Windows forwarded ports. Both short-name and FQDN mesh checks passed. No permanent root SSH mesh was established.

## Diagnose access without weakening host checks

Inspect effective Windows settings and port reachability:

```powershell
ssh -G ocne-op | Select-String '^(hostname|port|user|identityfile|hostkeyalias|userknownhostsfile|stricthostkeychecking) '
Test-NetConnection 127.0.0.1 -Port 2220
ssh -n -o BatchMode=yes ocne-op 'hostname; id -un'
```

Repeat with each alias and its port. A hosts lookup or ping alone does not test the configured SSH transport. A successful port probe does not verify guest identity; the pinned SSH connection does.

If OpenSSH reports bad ownership/permissions, inspect the included config and key ACLs. This run restricted the included config to the Windows user and SYSTEM after inherited permissions were rejected. Do not make the private key broadly readable.

If a host key changes unexpectedly, stop and verify its public fingerprint through that VM's console. Do not disable StrictHostKeyChecking or delete all known_hosts entries. Preserve old .lab.local mappings and unrelated hosts entries when making future updates. See [Troubleshooting](TROUBLESHOOTING.md).
