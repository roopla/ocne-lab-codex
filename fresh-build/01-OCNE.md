# 1. Setting up the OCNE lab

[Start and substitutions](README.md) | [Next: Database Operator](02-DATABASE-OPERATOR.md)

## 1a. Prerequisites

This generic path starts with four installed Linux hosts. Use any appropriate infrastructure after checking Oracle platform eligibility; VirtualBox is our local lab implementation. For existing golden VM clones, use the [cloning procedure](../docs/OCNE-1.9-Golden-VM-Cloning-Guide.md), preserve the source VM, and stop once guest identities, storage and SSH work. Do not also run fresh ISO scripts 02/03. Linux commands below are independent of the hypervisor.

### 1a.1 Prepare the host inventory

| Host / example IP | Fresh-build resources | Filesystems / purpose |
|---|---|---|
| ocne-op.lab.test / 192.168.77.10 | 2 vCPU, 8 GiB RAM | Operator CLI/API; at least 15 GB in /var |
| ocne-cp.lab.test / 192.168.77.11 | 4 vCPU, 16 GiB RAM | Control plane; XFS, at least 40 GB in /var |
| ocne-w1.lab.test / 192.168.77.12 | 6 vCPU, 22 GiB RAM | Worker; XFS, at least 15 GB in /var; dedicated 100 GiB XFS /var/lib/containers |
| ocne-w2.lab.test / 192.168.77.13 | 6 vCPU, 22 GiB RAM | Same as worker1 |

Operator/control-plane sizing meets Oracle minima here. The existing lab's 4/8 GiB allocation is a constrained exception, not validated capacity. Workers remain 22 GiB. These are individual guest sizes; reserve additional memory and storage for the host. A single control plane is not HA.

Install eligible Oracle Linux 9 x86_64 with UEK R7 (5.15 kernel family); Oracle's table permits latest/latest-1 OS updates, so check the table at build time. Use stable addresses, a sudo-capable labadmin account, Enforcing SELinux, working DNS or hosts entries, and direct Internet access. Provision dedicated container storage during OS preparation; never format an unidentified disk. Chapter 3 adds RAC scratch/shared disks and private NICs.

### 1a.2 Verify each prepared host

**Run:** all four hosts as labadmin.

```bash
hostname -f
cat /etc/oracle-release
uname -r
uname -m
cat /etc/machine-id
ip -br address
ip route
getent hosts ocne-op.lab.test ocne-cp.lab.test ocne-w1.lab.test ocne-w2.lab.test
id labadmin
sudo -v
free -h
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL
findmnt /var
getenforce
systemctl is-active chronyd firewalld sshd
chronyc tracking
getent hosts yum.oracle.com container-registry.oracle.com
curl -I --connect-timeout 15 https://container-registry.oracle.com/v2/
```

**Expected:** four distinct hostnames/machine IDs; intended IPs and routes; x86_64/eligible OL9/UEK R7; Enforcing; active services and synchronized time. Registry HTTP 200 or 401 proves HTTPS reachability, not image authorization. On each worker, `findmnt -M /var/lib/containers` must show its dedicated XFS mount.

**If not:** correct duplicate clone identities before installation; repair name resolution, upstream NTP/DNS, routes or OS eligibility. Use console access before changing the SSH interface. For hosts-file naming, preserve existing entries and add the four inventory mappings using `sudoedit /etc/hosts`, then repeat getent. Disk signatures or missing dedicated storage require inspection/provisioning, never a guessed mkfs command.

## 1b. Setting up

Run blocks in order, one role at a time. Stop at the first unexpected error. Commands use Bash on Linux, not PowerShell. Keep a second SSH/console connection for networking changes.

### 1b.1 Enable the OCNE 1.9 repositories

**Run:** all four hosts.

```bash
sudo dnf install oracle-olcne-release-el9

sudo dnf config-manager --enable ol9_olcne19 ol9_addons ol9_baseos_latest ol9_appstream ol9_UEKR7

sudo dnf config-manager --disable ol9_olcne18 ol9_olcne17

sudo dnf repolist --enabled
```

**Expected:** ol9_olcne19, addons, baseos_latest, appstream and UEKR7 enabled; OCNE 1.7/1.8 disabled.

**If not:** inspect actual repository IDs with `dnf repolist --all`. Disable any enabled developer/EPEL IDs using `sudo dnf config-manager --disable REPOSITORY_ID`; also resolve packages previously installed from those repos. Do not infer the stream from the release-package name: oracle-olcne-release-el9 may resolve to oracle-ocne-release-el9. If config-manager is missing, restore the OL9 DNF plugin tooling before continuing.

### 1b.2 Disable Kubernetes-node swap

**Run:** control plane and both workers.

```bash
sudo cp -a /etc/fstab /etc/fstab.before-ocne-$(date +%Y%m%d%H%M%S)
sudo swapoff -a
sudo sed -i '/^[[:space:]]*#/! { /[[:space:]]swap[[:space:]]/s/^/# OCNE swap disabled: /; }' /etc/fstab
swapon --show
sudo findmnt --verify --verbose
```

**Expected:** no active swap; fstab remains valid and only active swap records were commented.

**If not:** inspect `/etc/fstab` and any systemd swap units; repair the specific source and repeat. Do not remove other mount entries.

### 1b.3 Apply the non-HA Flannel firewall rules

**Run:** operator, workers, then control plane as marked.

Operator:

```bash
sudo firewall-cmd --add-port=8091/tcp --permanent
sudo systemctl restart firewalld.service
```

Each worker:

```bash
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --add-port=8090/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --add-port=10255/tcp --permanent
sudo firewall-cmd --add-port=8472/udp --permanent
sudo systemctl restart firewalld.service
```

Control plane:

```bash
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --add-port=8090/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --add-port=10255/tcp --permanent
sudo firewall-cmd --add-port=8472/udp --permanent
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo systemctl restart firewalld.service
```

```bash
sudo firewall-cmd --list-all
sudo firewall-cmd --zone=trusted --list-interfaces
```

**Expected:** success for each change; role-specific ports present and cni0 trusted on Kubernetes nodes.

**If not:** check `systemctl status firewalld` and the active zone (`sudo firewall-cmd --get-active-zones`). Apply the cited Oracle rules to the interface zone; check upstream firewalls too. Keep SSH allowed and SELinux enforcing.

### 1b.4 Persist Oracle Linux 9 forwarding and bridge support

**Run:** control plane and workers.

These paths are for new hosts. Inspect existing files before changing them.

```bash
sudo test ! -e /etc/nftables/forward-policies.nft || exit 1
sudo test ! -e /etc/systemd/system/forward-policies.service || exit 1
sudo install -d -m 0755 /etc/nftables
```

```bash
sudo sh -c "cat > /etc/nftables/forward-policies.nft << EOF
flush chain inet firewalld filter_FORWARD_POLICIES_post

table inet firewalld {
        chain filter_FORWARD_POLICIES_post {
                accept
        }
}
EOF"
```

```bash
sudo sh -c "cat > /etc/systemd/system/forward-policies.service << EOF
[Unit]
Description=Idempotent nftables rules for forward-policies
PartOf=firewalld.service

[Service]
ExecStart=/sbin/nft -f /etc/nftables/forward-policies.nft
ExecReload=/sbin/nft -f /etc/nftables/forward-policies.nft
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable forward-policies.service
sudo systemctl restart forward-policies.service
```

```bash
sudo modprobe br_netfilter
printf 'br_netfilter\n' | sudo tee /etc/modules-load.d/br_netfilter.conf
sudo nft list chain inet firewalld filter_FORWARD_POLICIES_post
sudo systemctl show forward-policies -p Result -p ExecMainStatus
lsmod | grep br_netfilter
```

**Expected:** forward chain contains accept, last service result success/exit 0, bridge module loaded. Oracle service Restart=always causes periodic restarts.

**If not:** inspect `sudo journalctl -u forward-policies -n 50` and firewalld chain existence; do not substitute a blanket firewall shutdown. After cluster installation verify bridge IPv4/IPv6 filtering and ip_forward are 1.

### 1b.5 Set up operator SSH

**Run:** operator as labadmin.

```bash
install -d -m 0700 ~/.ssh
# Create only when this key does not already exist; never overwrite it.
if test ! -e ~/.ssh/id_rsa; then ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa; fi
for host in ocne-op.lab.test ocne-cp.lab.test ocne-w1.lab.test ocne-w2.lab.test; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub "labadmin@$host"
  ssh -o BatchMode=yes "labadmin@$host" hostname -f
done
```

**Expected:** each expected hostname returned without an account-password prompt. Verify SSH fingerprints through console before first acceptance; a passphrase-protected key needs ssh-agent.

**If not:** check ownership/mode of ~/.ssh (700) and authorized_keys (600), host keys and routing. Password-free SSH does not imply password-free sudo.

### 1b.6 Install role packages

**Run:** operator and Kubernetes nodes separately.

Operator:

```bash
sudo dnf install olcnectl olcne-api-server olcne-utils
sudo systemctl enable olcne-api-server.service
```

Control plane and workers:

```bash
sudo dnf install olcne-agent olcne-utils
sudo systemctl enable olcne-agent.service
```

Operator, then log out and back in:

```bash
sudo usermod -a -G olcne labadmin
id
```

**Expected:** correct packages installed; services enabled but not yet bootstrapped; labadmin now belongs to olcne on operator.

**If not:** inspect `rpm -q olcnectl olcne-api-server olcne-utils` on operator and `rpm -q olcne-agent olcne-utils` on nodes. On clean Kubernetes nodes disable Docker/containerd only if running; OCNE installs CRI-O. Verify package-provided olcne sudo scope under /etc/olcne/scripts; do not grant labadmin blanket NOPASSWD.

### 1b.7 Generate and install private CA node certificates

**Run:** operator first; then each host for destination installation.

New PKI only; this uses Oracle generation with local interactive-sudo transport. Stop if the source directory already exists and inspect/reuse it.

```bash
cd "$HOME"
umask 077
test ! -e "$HOME/certificates" || { echo "Existing PKI: inspect and reuse it"; exit 1; }
olcnectl certificates generate --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test --cert-dir "$HOME/certificates"
ls -ld "$HOME/certificates" "$HOME/certificates/ca"
```

Operator, validate then stage each node:

```bash
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  openssl verify -CAfile "$HOME/certificates/ca/ca.cert" "$HOME/certificates/$node.lab.test/node.cert"
  openssl x509 -in "$HOME/certificates/$node.lab.test/node.cert" -noout -subject -dates -ext subjectAltName
done
```

```bash
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  ssh "$node.lab.test" 'umask 077; test ! -e ~/.ocne-cert-stage && mkdir -m 0700 ~/.ocne-cert-stage' || break
  scp "$HOME/certificates/ca/ca.cert" "$HOME/certificates/$node.lab.test/node.cert" "$HOME/certificates/$node.lab.test/node.key" "$node.lab.test:.ocne-cert-stage/" || break
done
```

Each host, logged in as labadmin (sudo may prompt):

```bash
set -euo pipefail
sudo -v
sudo test ! -e /etc/olcne/certificates/node.key
# If a destination already exists, stop and compare it rather than replacing trust.
sudo install -d -o olcne -g olcne -m 0755 /etc/olcne/certificates
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/ca.cert /etc/olcne/certificates/ca.cert
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/node.cert /etc/olcne/certificates/node.cert
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/node.key /etc/olcne/certificates/node.key
sudo restorecon -RF /etc/olcne/certificates
sudo openssl verify -CAfile /etc/olcne/certificates/ca.cert /etc/olcne/certificates/node.cert
sudo stat -c '%a %U:%G %n' /etc/olcne/certificates/ca.cert /etc/olcne/certificates/node.cert /etc/olcne/certificates/node.key
```

```bash
sudo openssl pkey -in /etc/olcne/certificates/node.key -pubout -outform DER | sha256sum
sudo openssl x509 -in /etc/olcne/certificates/node.cert -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum
```

Verify all four nodes received their intended files and that the two public-key hashes on each node match. After installed copies pass, on each host:

```bash
rm -- ~/.ocne-cert-stage/ca.cert ~/.ocne-cert-stage/node.cert ~/.ocne-cert-stage/node.key
rmdir -- ~/.ocne-cert-stage
```

**Expected:** all chains verify OK, SAN names/validity match nodes, files are olcne:olcne mode 600, and the two public-key hashes match.

**If not:** reuse existing CA after any copy failure. Inspect only the missing destination; do not regenerate trust, copy the CA private key to nodes, or overwrite installed keys. Stage directory left from a partial run must be inspected before reuse. The original automatic distribute failed on noninteractive sudo; this manual transport avoids that dependency. Securely back up the CA on the operator.

### 1b.8 Generate CLI and externalIPs certificates

**Run:** operator as labadmin.

```bash
olcnectl certificates generate \
  --nodes ocne-op.lab.test,192.168.77.10 \
  --cert-dir $HOME/.olcne/certificates/ocne-op.lab.test:8091/ \
  --byo-ca-cert $HOME/certificates/ca/ca.cert \
  --byo-ca-key $HOME/certificates/ca/ca.key \
  --one-cert

cp $HOME/certificates/ca/ca.cert \
  $HOME/.olcne/certificates/ocne-op.lab.test:8091/
```

```bash
olcnectl certificates generate \
  --nodes externalip-validation-webhook-service.externalip-validation-system.svc,externalip-validation-webhook-service.externalip-validation-system.svc.cluster.local \
  --cert-dir $HOME/certificates/restrict_external_ip/ \
  --byo-ca-cert $HOME/certificates/ca/ca.cert \
  --byo-ca-key $HOME/certificates/ca/ca.key \
  --one-cert

cp $HOME/certificates/ca/ca.cert $HOME/certificates/restrict_external_ip/
```

```bash
openssl verify -CAfile "$HOME/certificates/ca/ca.cert" "$HOME/.olcne/certificates/ocne-op.lab.test:8091/node.cert" "$HOME/certificates/restrict_external_ip/node.cert"
```

**Expected:** both certificates verify OK.

**If not:** keep API hostname/port and certificate directory identical. Replace the example operator IP when adapting the lab, but retain the two externalip-validation service DNS names.

### 1b.9 Bootstrap services

**Run:** operator and Kubernetes nodes separately.

Operator:

```bash
sudo /etc/olcne/bootstrap-olcne.sh \
  --secret-manager-type file \
  --olcne-component api-server

systemctl status olcne-api-server.service
```

Control plane and workers:

```bash
sudo /etc/olcne/bootstrap-olcne.sh \
  --secret-manager-type file \
  --olcne-component agent

systemctl status olcne-agent.service
```

**Expected:** api-server active on operator; agent active on all three cluster nodes.

**If not:** inspect the named unit with `sudo journalctl -u UNIT -n 80`, certificate permissions/SANs, time and listening ports. Resolve failures before creating an environment.

### 1b.10 Create environment and Kubernetes module

**Run:** operator as labadmin.

```bash
olcnectl environment create \
  --api-server ocne-op.lab.test:8091 \
  --environment-name homelab \
  --secret-manager-type file \
  --update-config
```

```bash
olcnectl module create \
  --environment-name homelab \
  --module kubernetes --name cluster1 \
  --container-registry container-registry.oracle.com/olcne \
  --control-plane-nodes ocne-cp.lab.test:8090 \
  --worker-nodes ocne-w1.lab.test:8090,ocne-w2.lab.test:8090 \
  --selinux enforcing \
  --restrict-service-externalip-ca-cert $HOME/certificates/restrict_external_ip/ca.cert \
  --restrict-service-externalip-tls-cert $HOME/certificates/restrict_external_ip/node.cert \
  --restrict-service-externalip-tls-key $HOME/certificates/restrict_external_ip/node.key
```

**Expected:** homelab environment and cluster1 module created using file certificates, Flannel and SELinux enforcing.

**If not:** inventory existing objects with `olcnectl module instances --environment-name homelab` (use `olcnectl environment --help` for environment commands); inspect a partial run instead of recreating an occupied environment. Nodes cannot belong to two environments.

### 1b.11 Validate, install and report

**Run:** operator as labadmin.

```bash
olcnectl module validate \
  --environment-name homelab \
  --name cluster1
```

Only if validation fails, generate corrections:

```bash
olcnectl module validate \
  --environment-name homelab \
  --name cluster1 \
  --generate-scripts
```

Review every generated node script, run it on its named Linux node, and repeat validation. After validation passes:

```bash
olcnectl module install \
  --environment-name homelab \
  --name cluster1
```

```bash
olcnectl module report \
  --environment-name homelab \
  --name cluster1 \
  --children
```

**Expected:** validation passes, install exits successfully, report shows healthy cluster/children.

**If not:** review each reported dependency/firewall failure. Generated hostname:8090.sh files stay on Linux. For slow image downloads inspect progress and logs; never start a second installer or bootstrap a separate kubeadm cluster.

### 1b.12 Configure kubectl and accept the cluster

**Run:** control plane as labadmin.

```bash
install -d -m 0700 "$HOME/.kube"
test ! -e "$HOME/.kube/config" || { echo 'Inspect existing kubeconfig'; exit 1; }
sudo install -o "$(id -u)" -g "$(id -g)" -m 0600 /etc/kubernetes/admin.conf "$HOME/.kube/config"
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes -o wide
kubectl get deployments -A
kubectl get pods -A -o wide
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl wait --for=condition=Ready pods --all -A --timeout=180s
```

On control plane and both workers:

```bash
swapon --show
sysctl net.bridge.bridge-nf-call-ip6tables net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
findmnt -M /var/lib/containers
getenforce
```

**Expected:** three nodes Ready (operator is not a Kubernetes node), all base pods Ready, deployment replicas available, no swap, sysctls 1 and SELinux Enforcing. Dedicated container XFS mount is mandatory on workers.

**If not:** use `kubectl get events -A --sort-by=.metadata.creationTimestamp`, `kubectl describe node NODE`, and `sudo journalctl -u kubelet -u crio -n 100` on the affected host. Fix CNI/firewall/images/resources before chapter 2. A healthy olcnectl summary does not override failing direct checks.

**Optional lab addition:** the operator's separate 100 GiB NFS share is not RAC ASM storage or an OCNE prerequisite. To reproduce it, follow [Part D, disk identity through read/write checks](../docs/OCNE-1.9-OL9-Setup-Guide.md#part-d-additional-100-gib-nfs-server-on-the-operator). Keep matching labadmin UID/GID, root squashing, SELinux and existing exports. It is outside this minimal path.

Sources: [OCNE 1.9 host requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html), [prerequisites](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html), [installation/certificates](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html), [environment](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/env-create.html), [Kubernetes continuation](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/deploy-kube-intro.html), [kubectl](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/kubectl-intro.html). This is a condensed adaptation; [original source attribution/license](../docs/OCNE-1.9-OL9-Setup-Guide.md#attribution-and-license) remains applicable.
