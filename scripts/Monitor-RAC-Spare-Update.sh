#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp ]]
date -u
kubectl get pods,pvc -n rac -o wide
python3 <<'PY'
import json,subprocess
for kind in ('racdatabase','sts','pods','pv'):
 d=json.loads(subprocess.check_output(['kubectl','get',kind,'-n','rac','-o','json']))
 for x in d['items']:
  print(kind,x['metadata']['name'])
  if kind=='racdatabase':
   print('Generation',x['metadata']['generation'],'Observed',x.get('status',{}).get('observedGeneration'))
   print('Spec ASM:',x['spec']['asmDiskGroupDetails'])
   print('State:',x.get('status',{}).get('state'),'Conditions:',x.get('status',{}).get('conditions'),'Operation:',x.get('status',{}).get('operation'))
  if kind in ('sts','pods'):
   spec=x['spec']['template']['spec'] if kind=='sts' else x['spec']
   print('UID',x['metadata']['uid'],'strategy',x['spec'].get('updateStrategy'))
   for c in spec['containers']: print('Devices',c.get('volumeDevices'))
  if kind=='pv':print(x['spec'].get('local'),x['spec'].get('volumeMode'),x.get('status'))
PY
kubectl logs -n oracle-database-operator-system deployment/oracle-database-operator-controller-manager -c manager --since=2m --tail=45
