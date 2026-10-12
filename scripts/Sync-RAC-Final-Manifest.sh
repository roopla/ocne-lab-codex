#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
manifest=$HOME/ocne-rac-prereqs/rac-database-live.yaml
printf '%s  %s\n' c55338afabd3f618126860abf8ae166a5b487cb9d436f575f1c27cbfb50e8a53 "$manifest" | sha256sum -c -
kubectl apply --dry-run=server -f "$manifest"
kubectl apply -f "$manifest"
python3 <<'PY'
import json,subprocess
for n in (1,2):
 patch={'spec':{'template':{'spec':{'containers':[{'name':f'racnode{n}-0','env':[{'name':'ORACLE_PDB_NAME','value':'LABPDB'}]}]}}}}
 subprocess.run(['kubectl','patch','statefulset',f'racnode{n}','-n','rac','--type=strategic','-p',json.dumps(patch)],check=True)
p=json.loads(subprocess.check_output(['kubectl','get','racdatabase','rac19c','-n','rac','-o','json']))
assert p['spec']['serviceDetails']['name']=='labpdb'
assert p['spec']['configParams']['sgaSize']=='3G'
assert all('hugepages-2Mi' not in p['spec']['resources'][k] for k in ('limits','requests'))
print('Current CR retains the immutable legacy service name; SGA and no-HugePages profile verified.')
PY
kubectl get pods -n rac -o wide
