#!/bin/bash
# Fault each reserved HugePage, then release this script's temporary file.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(sysctl -n vm.nr_hugepages) == 1536 ]]
[[ $(findmnt -nro FSTYPE -M /dev/hugepages) == hugetlbfs ]]
python3 <<'PY'
import mmap,os,tempfile
from pathlib import Path
def meminfo():
 return {line.split(':')[0]:int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines()}
before=meminfo()
assert before['HugePages_Total']==before['HugePages_Free']==1536
assert before['HugePages_Rsvd']==0 and before['Hugepagesize']==2048
fd,path=tempfile.mkstemp(prefix='ocne-rac-hugepage-check-',dir='/dev/hugepages')
try:
 size=3*1024**3
 os.ftruncate(fd,size)
 with mmap.mmap(fd,size,mmap.MAP_SHARED,mmap.PROT_READ|mmap.PROT_WRITE) as region:
  for offset in range(0,size,2*1024**2): region[offset]=1
  assert meminfo()['HugePages_Free']==0
  print('Allocated and touched all 1536 HugePages (3 GiB).')
finally:
 os.close(fd)
 os.unlink(path)
assert meminfo()['HugePages_Free']==1536
print('Released test allocation; all 1536 HugePages free again.')
PY
