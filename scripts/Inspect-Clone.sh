set -euo pipefail
hostnamectl --static
uname -r
cat /etc/machine-id
id labadmin
ip -br -4 address
ip route
getent hosts ocne-op ocne-cp ocne-w1 ocne-w2
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/
findmnt -T /var
findmnt -t vboxsf || test $? = 1
grib=none
grubby --default-kernel
getenforce
getent ahostsv4 yum.oracle.com container-registry.oracle.com
printf 'Clone SSH inspection complete\n'