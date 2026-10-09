#!/bin/bash
# Guide B1-B2, Oracle OCNE 1.9 Installation prerequisites.
set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
[[ $(uname -r) == 5.15.*el9uek.x86_64 ]]
[[ $(getenforce) == Enforcing ]]
[[ $(df -B1 --output=avail /var | tail -1) -ge 42949672960 ]]
dnf config-manager --help >/dev/null
rpm -q oracle-olcne-release-el9 || dnf -y install oracle-olcne-release-el9
dnf config-manager --enable ol9_olcne19 ol9_addons ol9_baseos_latest ol9_appstream ol9_UEKR7
dnf config-manager --disable ol9_olcne18 ol9_olcne17
mapfile -t devrepos < <(dnf -q repolist --enabled | awk '$1 ~ /developer|[Ee][Pp][Ee][Ll]/ {print $1}')
if ((${#devrepos[@]})); then dnf config-manager --disable "${devrepos[@]}"; fi
if dnf -q list installed | grep -Ei '@[^[:space:]]*(developer|epel)'; then echo 'Installed developer/EPEL software requires review'; exit 1; fi
dnf repolist --enabled
[[ $(timedatectl show -p NTPSynchronized --value) == yes ]]
chronyc tracking
curl -I --connect-timeout 15 --max-time 30 https://yum.oracle.com/
curl -I --connect-timeout 15 --max-time 30 https://container-registry.oracle.com/v2/
grubby --default-kernel
printf 'OCNE repositories, time, and registry connectivity checked\n'