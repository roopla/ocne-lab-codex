#!/bin/bash
# Authorized rebuild-kit preparation only. Does not install RPMs or alter workloads.
set -euo pipefail
[[ $(id -u) == 0 ]]
node=$(hostname -s)
case "$node" in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
if [[ "$node" == ocne-w* ]]; then base=/scratch/rebuild-kit-20261016; else base=/var/tmp/rebuild-kit-20261016; fi
[[ $(df -B1 --output=avail "$(dirname "$base")" | tail -1) -gt 17179869184 ]]
install -d -m 0750 -o labadmin -g labadmin "$base"
export REBUILD_KIT_BASE="$base"
python3 <<'PY'
import json,os,subprocess,pathlib
base=pathlib.Path(os.environ['REBUILD_KIT_BASE'])
images=json.loads(subprocess.check_output(['podman','images','--format','json']))
rows=[{k:i.get(k) for k in ('Id','Names','Digest','Size')} for i in images]
(base/'image-inventory.json').write_text(json.dumps(rows,indent=2))
selected=[]
for image in rows:
 names=image['Names'] or []
 if not any(n.startswith(('container-registry.oracle.com/','quay.io/jetstack/','docker.io/roopla/oracle-rac','docker.io/library/busybox')) for n in names):continue
 named=next((n for n in names if '@' not in n),image['Id'])
 selected.append(named)
archive=base/'platform-images.tar'
if archive.exists():raise SystemExit('Export already exists; verify the existing archive before deciding whether a new export is needed')
if selected:
 subprocess.run(['nice','-n','10','podman','save','--quiet','--multi-image-archive','--format','docker-archive','--output',str(archive)+'.partial',*selected],check=True)
 pathlib.Path(str(archive)+'.partial').replace(archive)
print('EXPORTED_PLATFORM_IMAGES',len(selected),flush=True)
(base/'installed-rpms.txt').write_bytes(subprocess.check_output(['rpm','-qa','--qf','%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n']))
PY
chown -R labadmin:labadmin "$base"
find "$base" -maxdepth 1 -type f -exec chmod 0640 {} +
[[ ! -f "$base/platform-images.tar" ]] || sha256sum "$base/platform-images.tar"
echo "GUEST_IMAGE_EXPORT_COMPLETE $node $base"
