#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1) n=1;; ocne-w2) n=2;; *) exit 1;; esac
path=/scratch/rac/cluster01/racnode$n/app/grid/.etcoraclebackup
[[ $(findmnt -nro FSTYPE -T "$path") == xfs ]]
ls -ldZ "$path" "$path/oracle" "$path/oracle/olr.loc"
matchpathcon "$path/oracle/olr.loc"
restorecon -RFv "$path"
ls -ldZ "$path" "$path/oracle" "$path/oracle/olr.loc"
