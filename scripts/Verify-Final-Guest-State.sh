set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
uname -r
[[ $(uname -r) == 5.15.*el9uek* && $(getenforce) == Enforcing ]]
cat /etc/machine-id
id labadmin
[[ $(id -u labadmin) == 1001 && $(id -g labadmin) == 1001 ]]
! findmnt -t vboxsf >/dev/null
systemctl --failed --no-pager
firewall-cmd --list-ports
case $(hostname -s) in
 ocne-op)
  systemctl is-active olcne-api-server nfs-server
  findmnt -n -o SOURCE,UUID,FSTYPE,TARGET -M /srv/nfs
  ;;
 *)
  systemctl is-active olcne-agent crio kubelet
  nft list chain inet firewalld filter_FORWARD_POLICIES_post
  nft list chain inet firewalld filter_FORWARD_POLICIES_post | grep -q 'accept'
  [[ -z $(swapon --show --noheadings) ]]
  ;;
esac
case $(hostname -s) in ocne-w1|ocne-w2) findmnt -n -o SOURCE,UUID,FSTYPE,TARGET -M /var/lib/containers;; esac