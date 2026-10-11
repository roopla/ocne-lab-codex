#!/bin/bash
set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
for serial in VBdb34f551-507d0f5a VBc280454f-7e0f28bc; do
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="$serial" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$disk")
 [[ -z "$signatures" ]]
 printf 'Blank ASM disk verified: %s %s\n' "$disk" "$serial"
done
scratch=$(findmnt -nro SOURCE -M /scratch)
signatures=$(wipefs --no-act --noheadings --output TYPE "$scratch")
[[ $signatures == xfs ]]
printf 'Scratch signature detected correctly: %s %s\n' "$scratch" "$signatures"
findmnt -n -o SOURCE,UUID,FSTYPE,TARGET -M /scratch
