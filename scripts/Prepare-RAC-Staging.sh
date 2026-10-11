#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ ! -e /scratch/software/stage/19c/19.32 ]]
install -d -o root -g root -m 0755 /scratch/software /scratch/software/stage /scratch/software/stage/19c
install -d -o labadmin -g labadmin -m 0755 /scratch/software/stage/19c/19.32
stat -c '%u:%g %a %n' /scratch/software/stage/19c/19.32
