#!/bin/bash
# Match the image's 19c ASM device ownership for the new candidates only.
# Recheck after future pod replacement; container device nodes are recreated.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
for n in 1 2; do
 kubectl exec -i -n rac "racnode$n-0" -- bash -s <<'PERMS'
set -euo pipefail
[[ $(id -u) == 0 ]]
id grid
getent group asmadmin
for name in ocne-rac-asm03 ocne-rac-asm04; do
 disk=/dev/disk/by-partlabel/$name
 [[ -b $disk && $(blockdev --getsize64 "$disk") == 53684994048 ]]
 chown grid:asmadmin "$disk"
 chmod 0660 "$disk"
 stat -c '%U:%G %a %n' "$disk"
done
PERMS
done
