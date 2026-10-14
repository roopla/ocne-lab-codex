#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
date -u
kubectl get nodes
kubectl get racdatabase rac19c -n rac
kubectl get pods,pvc -n rac -o wide
kubectl get pods -n rac-app -o wide
python3 <<'PY'
import json,subprocess
for node in json.loads(subprocess.check_output(['kubectl','get','nodes','-o','json']))['items']:
 assert any(c['type']=='Ready' and c['status']=='True' for c in node['status']['conditions'])
app=json.loads(subprocess.check_output(['kubectl','get','pods','-n','rac-app','-o','json']))['items']
assert len(app)==8
assert all(any(c['type']=='Ready' and c['status']=='True' for c in p['status']['conditions']) for p in app)
for host in ('192.168.77.12','192.168.77.13'):
 url=f'http://{host}:30080/api/status'
 data=json.loads(subprocess.check_output(['curl','--fail','--max-time','25','-sS',url]))
 print(url,json.dumps(data,indent=2))
 assert all(x['healthy'] and x['pdb']=='LABPDB' and x['mode']=='oracle' for x in data['services'].values())
print('PASS: three Ready nodes, eight Ready app pods, both worker HTTP paths query Oracle LABPDB')
PY
for n in 1 2; do
 echo "Startup observations: racnode$n-0"
 kubectl exec -n rac "racnode$n-0" -- bash -c 'grep -E "CRS-4640|CRS-4000|INS-40401|Permission denied|Total time for setup" /tmp/orod/oracle_db_setup.log || test $? = 1'
done
