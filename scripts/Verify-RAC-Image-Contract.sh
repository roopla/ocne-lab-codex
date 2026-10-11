#!/bin/bash
set -euo pipefail
image=docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
podman image inspect "$image" | python3 -c 'import json,sys; env=json.load(sys.stdin)[0]["Config"].get("Env",[]); keys={v.split("=",1)[0] for v in env}; forbidden=keys.intersection({"APPLY_RU_LOCATION","OPATCH_ZIP_FILE","ONEOFF_FOLDER_NAME","GRID_ONEOFF_IDS","DB_ONEOFF_IDS"}); assert not forbidden, "Image embeds patch inputs: "+str(forbidden); print("No deployment-time patch inputs in image environment.")'
m=$(podman image mount "$image")
trap 'podman image unmount "$image" >/dev/null' EXIT
for f in usr/lib/systemd/systemd usr/bin/python3 opt/scripts/startup/scripts/cmdExec; do [[ -x "$m/$f" ]]; done
[[ -f "$m/opt/scripts/startup/scripts/main.py" ]]
python3 - "$m" <<'PY'
import ast,sys,pathlib
p=pathlib.Path(sys.argv[1])/'opt/scripts/startup/scripts'
files=list(p.glob('*.py'))
for f in files: ast.parse(f.read_text())
print('Parsed %s RAC Python scripts; main.py/cmdExec/systemd/python3 present.' % len(files))
for name in ('oragiprov.py','oraracprov.py','oracommon.py','oraenv.py'):
 for i,line in enumerate((p/name).read_text().splitlines(),1):
  if any(t in line for t in ('applyRU','applyOneOffs','gridSwZipFile','dbSwZipFile','RU_PATCH','ru_patch','opatch_location','pkeyutl','34436514')): print('%s:%s:%s' % (name,i,line.strip()))
PY
