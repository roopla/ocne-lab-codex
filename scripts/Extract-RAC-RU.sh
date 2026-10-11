#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;; ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;; *) exit 1;; esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
base=/scratch/software/stage/19c/19.32
[[ ! -e $base/RU && ! -e $base/OPATCH ]]
[[ $(df --output=avail -B1 /scratch | tail -1) -gt 90000000000 ]]
cd "$base"
printf '%s  %s\n' 5eba8519ac16e7eb2701f977b5f81f0e7f49225da1f430966bdc8fed9e649198 p39467003_190000_Linux-x86-64.zip | sha256sum -c -
install -d -m 0755 RU OPATCH
# This only extracts patch files; it does not run any installer or patch tool.
unzip -q -n p39467003_190000_Linux-x86-64.zip -d RU
[[ -d RU/39467003/39472050 ]]
cp -p p6880880_190000_Linux-x86-64.zip OPATCH/
chmod 0755 ./*.zip OPATCH/*.zip
chmod -R 0755 RU
chown -R 54321:54321 "$base"
restorecon -RF "$base"
find RU/39467003 -maxdepth 1 -mindepth 1 -type d -printf '%f\n'
stat -c '%u:%g %a %n' "$base" "$base/RU/39467003" "$base/OPATCH/p6880880_190000_Linux-x86-64.zip"
df -h /scratch
