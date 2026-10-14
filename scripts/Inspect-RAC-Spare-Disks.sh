#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1) n=1;; ocne-w2) n=2;; *) exit 1;; esac
date -u
hostname
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,PARTLABEL,PARTUUID,SERIAL
for disk in /dev/sd?; do
 echo "Read-only signatures: $disk"
 wipefs -n "$disk"
done
path=/scratch/rac/cluster01/racnode$n/app/grid/.etcoraclebackup
ls -ldZ "$path" "$path/oracle" "$path/oracle/olr.loc"
matchpathcon "$path/oracle/olr.loc"
getenforce
findmnt /scratch
