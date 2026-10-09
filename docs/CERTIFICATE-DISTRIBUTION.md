# OCNE certificate distribution: prerequisites and recorded recovery

This supplements installation guide B9–B13. The completed lab already has functioning certificates and services; do not regenerate or redistribute them as a routine health check.

Oracle procedure: [Installing OCNE 1.9](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html), certificate and startup sections; [Platform CLI commands](https://docs.oracle.com/en/operating-systems/olcne/1.9/olcnectl/commands.html), Certificates Copy/Distribute. The temporary SSH authorization and transport cleanup below are local orchestration, not additional Oracle requirements.

## Check privileges before distribution

Password-free SSH as labadmin does not imply password-free sudo. In this lab, labadmin keeps password-required sudo; the package-created olcne account has its separate package-provided scope for /etc/olcne/scripts.

Before a new installation's distribution step, verify node resolution, time, host-key pins, SSH authentication, the operator's olcne group membership, and the actual remote privilege path. A noninteractive copy cannot depend on an unseen password prompt. Do not solve this with blanket labadmin NOPASSWD rules.

If generation succeeded but copying failed, inspect existing files and retain the CA/node material. Determine which destination copies completed before attempting recovery. Regenerating the CA can break trust in already configured components.

## What happened in this lab

1. Guide B10's distribute operation ran as labadmin and generated the PKI, then failed on noninteractive sudo.
2. The generated material under /home/labadmin/certificates was preserved.
3. A temporary operator public key was added to root's authorized_keys on the four clones, restricted to source 192.168.77.10, with agent/port/X11 forwarding and PTY disabled. Existing root keys were preserved.
4. The documented copy command ran as root on the operator, using the existing PKI and pinned SSH identities.
5. Destination certificate files, ownership, chain validation and subsequently running services were independently checked.
6. The copy transport remained stuck after copying. The specifically identified copy process and orphaned SSH transports were terminated after verification; this was not recorded as a normal successful command exit.
7. The exact temporary root authorization was removed from every clone and absence verified.

The recorded copy command, for reference only:

```bash
# Historical recovery: root on ocne-op, after reviewed temporary access was established.
cd /home/labadmin
olcnectl certificates copy \
  --cert-dir /home/labadmin/certificates \
  --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test \
  --ssh-identity-file /home/labadmin/.ssh/id_rsa \
  --ssh-login-name root \
  --remote-command 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/labadmin/.ssh/known_hosts'
```

Do not paste this onto a healthy lab. A future failed distribution requires a fresh inspection of policy, identity, PKI and process state. Temporary root access was removed, not retained as the permanent mesh.

## Verification before service bootstrap

On each intended guest, as an authorized administrator:

```bash
sudo test -s /etc/olcne/certificates/ca.cert
sudo test -s /etc/olcne/certificates/node.cert
sudo test -s /etc/olcne/certificates/node.key
sudo openssl verify \
  -CAfile /etc/olcne/certificates/ca.cert \
  /etc/olcne/certificates/node.cert
sudo openssl x509 -in /etc/olcne/certificates/node.cert \
  -noout -subject -issuer -dates -ext subjectAltName
sudo stat -c '%a %U:%G %n' /etc/olcne/certificates/ca.cert \
  /etc/olcne/certificates/node.cert /etc/olcne/certificates/node.key
```

Check every command result, intended certificate identity, validity, correct ownership for the platform service and restrictive private-key access. These commands display metadata, not private-key contents. Then follow guide B11/B12 for the CLI and externalIPs certificates and B13 for bootstrap. Verify olcne-api-server on the operator and olcne-agent on each cluster node.

Keep the labadmin CLI endpoint and directory consistent: ocne-op.lab.test:8091 and /home/labadmin/.olcne/certificates/ocne-op.lab.test:8091/. Keep the externalIPs certificate path consistent with module creation.

## Recovery helpers are historical

Authorize-Certificate-Copy.sh and Remove-Certificate-Copy-Key.sh embed this run's public key. Stop-Stalled-Certificate-Copy.sh and **Inspect-Certificate-Transports.sh** contain historical process IDs and can send SIGTERM. The latter is not read-only despite its name. Do not rerun them against today's process table.

Review a new incident and match the full current process identity before any termination; never kill by a recorded PID alone. Preserve evidence and remove temporary access even if a later stage fails.

Certificate renewal/rotation and restoration from backup were not exercised in this installation. Follow the cited Oracle lifecycle guidance for that separate operation, preserving the current trust chain until a reviewed replacement procedure is ready.

Actual results: [cloning log](CLONING-RUN-LOG.md). Execution contexts: [script reference](SCRIPT-REFERENCE.md).
