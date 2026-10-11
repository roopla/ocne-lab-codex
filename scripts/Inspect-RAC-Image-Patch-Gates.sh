#!/bin/bash
set -euo pipefail
image=docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
m=$(podman image mount "$image")
trap 'podman image unmount "$image" >/dev/null' EXIT
sed -n '325,375p' "$m/opt/scripts/startup/scripts/oraracprov.py"
sed -n '1760,1815p' "$m/opt/scripts/startup/scripts/oracommon.py"
python3 - "$m/opt/scripts/startup/scripts/oracommon.py" <<'PY'
import ast,pathlib,sys
src=pathlib.Path(sys.argv[1]).read_text()
for n in ast.walk(ast.parse(src)):
 if isinstance(n,ast.FunctionDef) and n.name=='opatch_apply':
  print('\n'.join(src.splitlines()[n.lineno-1:min(n.end_lineno,n.lineno+24)]))
PY
