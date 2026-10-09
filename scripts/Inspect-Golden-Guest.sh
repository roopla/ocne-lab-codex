set -u
export LC_ALL=C
printf '\nOS and kernel\n'
cat /etc/oracle-release
uname -rmo
rpm -q oraclelinux-release kernel-uek kernel-uek-core
hostnamectl
printf '\nStorage and mounts\n'
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
findmnt -T /var
findmnt -T /var/lib/containers
findmnt -t vboxsf
findmnt -rn -o SOURCE,TARGET,FSTYPE
 df -hT / /var
pvs --units g
vgs --units g
lvs --units g -o lv_name,vg_name,lv_size,lv_path
printf '\nAccounts\n'
id
id labadmin
getent passwd | awk -F: '$3 == 0 || ($3 >= 1000 && $3 < 65534) {print $1 ": uid=" $3 ", gid=" $4 ", home=" $6 ", shell=" $7}'
getent group wheel
printf '\nNetwork and services\n'
nmcli -f NAME,UUID,TYPE,DEVICE connection show
nmcli -f GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show enp0s3
nmcli -f NAME,UUID,FILENAME connection show
ip route
systemctl is-active NetworkManager sshd firewalld chronyd
systemctl is-enabled cloud-init.service
getenforce
firewall-cmd --get-active-zones
firewall-cmd --list-all
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
printf '\nInstalled software of interest\n'
rpm -qa | sort | grep -Ei '^(olcne|kube|cri-o|containerd|docker|podman|cloud-init|openssh-server|NetworkManager|oracle.*(database|preinstall)|kmod.*vbox|virtualbox|puppet|chef|salt|ansible)'
printf '\nExisting application state paths (metadata only)\n'
for path in /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/olcne /etc/sysconfig/rhn/systemid /var/lib/containers /etc/oracle /u01 /etc/cloud /var/lib/cloud; do
    if [ -e "$path" ]; then ls -ld "$path"; else printf 'ABSENT %s\n' "$path"; fi
done
printf '\nContainer storage contents (metadata only)\n'
if [ -d /var/lib/containers ]; then find /var/lib/containers -maxdepth 2 -type d; fi
printf '\nEnabled automation units\n'
systemctl list-unit-files --state=enabled --no-pager | grep -Ei 'cloud|puppet|chef|salt|ansible|vbox|oracle|olcne|kube|docker|container|podman'
printf '\nRepository IDs (cached, no refresh)\n'
dnf -C repolist --enabled
printf '\nInspection completed\n'