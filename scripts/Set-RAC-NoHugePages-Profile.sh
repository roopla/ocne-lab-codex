#!/bin/bash
# Reconcile the no-HugePages profile without restarting the configured GI pods.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import json,subprocess,pathlib,datetime

def k(*args,data=None):
 p=subprocess.run(['kubectl',*args],input=data,capture_output=True,text=True)
 if p.returncode: raise RuntimeError('kubectl failed: '+p.stderr)
 return p.stdout
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert cr['status']['state']=='PENDING'
backup=pathlib.Path.home()/('ocne-rac-prereqs/pre-nohugepages-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
backup.mkdir(mode=0o700)
(backup/'racdatabase.json').write_text(json.dumps(cr,indent=2))
for n in (1,2):
 pod=f'racnode{n}-0'; sts=f'racnode{n}'
 mem=k('exec','-n','rac',pod,'--','cat','/proc/meminfo')
 assert any(line.split()==['HugePages_Total:','0'] for line in mem.splitlines())
 ps=k('exec','-n','rac',pod,'--','ps','-eo','comm')
 assert 'ora_pmon' not in ps
 assert k('exec','-n','rac',pod,'--','sysctl','-n','kernel.shmall','kernel.shmmax').split()==['2097152','8589934592']
 obj=json.loads(k('get','statefulset',sts,'-n','rac','-o','json'))
 (backup/(sts+'.json')).write_text(json.dumps(obj,indent=2))
 # OnDelete prevents an incidental simultaneous GI restart while updating immutable pod inputs.
 patch={'spec':{'updateStrategy':{'type':'OnDelete','rollingUpdate':None}}}
 k('patch','statefulset',sts,'-n','rac','--type=merge','-p',json.dumps(patch))
 print(pod+': live shared-memory limits set; existing Clusterware retained')
# Preserve all storage/network/software settings. Only requested memory settings change.
resources=cr['spec']['resources']
for section in ('requests','limits'): resources[section].pop('hugepages-2Mi',None)
sc=cr['spec']['securityContext']
for entry in sc['sysctls']:
 if entry['name']=='kernel.shmall': entry['value']='2097152'
 if entry['name']=='kernel.shmmax': entry['value']='8589934592'
env=cr['spec']['envVars']
for entry in env:
 if entry['name']=='TOTAL_MEMORY': entry['value']='16384'
patch={'spec':{'resources':resources,'securityContext':sc,'envVars':env}}
# JSON merge must explicitly remove the existing map keys.
for section in ('requests','limits'):patch['spec']['resources'][section]['hugepages-2Mi']=None
print(k('patch','racdatabase','rac19c','-n','rac','--type=merge','-p',json.dumps(patch)))
for n in (1,2):
 sts=f'racnode{n}'
 res={sec:{key:value for key,value in values.items() if value is not None} for sec,values in resources.items()}
 patch={'spec':{'template':{'spec':{'securityContext':sc,'containers':[{'name':f'racnode{n}-0','resources':{sec:{**vals,'hugepages-2Mi':None} for sec,vals in res.items()},'env':env}]}}}}
 print(k('patch','statefulset',sts,'-n','rac','--type=strategic','-p',json.dumps(patch)))
print('Desired templates no longer request HugePages. Existing pod resource fields persist until a controlled restart; kernel pools are already zero.')
PY
