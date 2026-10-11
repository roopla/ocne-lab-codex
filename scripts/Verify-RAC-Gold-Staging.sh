#!/bin/bash
# Verify exact archive content before setting shared read permissions.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
cd /scratch/software/stage/19c/19.32-gold
[[ -f oracle-dbhome-19.32.zip && ! -L oracle-dbhome-19.32.zip ]]
[[ -f oracle-gridhome-19.32.zip && ! -L oracle-gridhome-19.32.zip ]]
sha256sum -c <<'HASHES'
da75d72a2c1491d129e70ac0c3cdbb86c19024d5d80931f0e9c7714d25ef7e5f  oracle-dbhome-19.32.zip
d02d04276e767d7715006fa3690851f2203ff578ff35e963e18b67b15ddcc917  oracle-gridhome-19.32.zip
HASHES
chmod 0755 oracle-dbhome-19.32.zip oracle-gridhome-19.32.zip
chown 54321:54321 oracle-dbhome-19.32.zip oracle-gridhome-19.32.zip
restorecon -RF /scratch/software/stage/19c/19.32-gold
for f in oracle-dbhome-19.32.zip oracle-gridhome-19.32.zip; do
 [[ $(stat -c '%u:%g:%a' "$f") == 54321:54321:755 ]]
 ls -lZ "$f" | grep container_file_t
done
[[ $(df --output=avail -B1 /scratch | tail -1) -gt 40000000000 ]]
df -h /scratch
