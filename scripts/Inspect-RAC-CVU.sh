#!/bin/bash
set -euo pipefail
[[ $(id -un) == labadmin ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
cd /scratch/tools/cvu-23.26.3
printf '%s  %s\n' 23da73fed4b9403f933a5bbb8e75e9b6931ed5fd33fd1dbfc6503227de70bdc8 cvupack_linux_ol8_x86_64.zip | sha256sum -c -
[[ ! -e bin ]]
unzip -q -n cvupack_linux_ol8_x86_64.zip
./bin/cluvfy -version
./bin/cluvfy -help
