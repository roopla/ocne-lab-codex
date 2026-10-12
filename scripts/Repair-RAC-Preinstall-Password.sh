#!/bin/bash
# One-time recovery of this lab's pre-CRS INS-30003 failure. Does not restart setup.
set -euo pipefail
set +x
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 -u <<'PY'
import subprocess,json,pathlib,os,secrets,string,base64,hashlib,time,datetime,shutil
os.umask(0o077)
def run(args, data=None):
 p=subprocess.run(args,input=data,capture_output=True)
 if p.returncode: raise RuntimeError('Command failed without exposing credential output: '+args[0])
 return p.stdout
def k(*args): return run(['kubectl',*args])
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert cr['status']['state']=='PENDING'
for pod in ('racnode1-0','racnode2-0'):
 k('exec','-n','rac',pod,'--','test','!','-e','/etc/oracle/ocr.loc')
 ps=k('exec','-n','rac',pod,'--','ps','-eo','comm').decode()
 assert not any(x in ps for x in ('ora_pmon','asm_pmon','java','python3'))
d=pathlib.Path.home()/'.local/share/ocne-rac-secrets'
assert len((d/'db-password.txt').read_text())==32
backup=d/('pre-ins30003-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
backup.mkdir(mode=0o700)
for name in ('db-password.txt','pwdfile.enc'): shutil.copy2(d/name,backup/name)
new=backup/'replacement-password.txt'
new.write_text('Rac_9'+''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(19)))
enc=backup/'replacement-pwdfile.enc'
opts=['-pkeyopt','rsa_padding_mode:oaep','-pkeyopt','rsa_oaep_md:sha256','-pkeyopt','rsa_mgf1_md:sha256']
run(['openssl','pkeyutl','-encrypt','-pubin','-inkey',str(d/'key.pub'),'-in',str(new),'-out',str(enc),*opts])
assert run(['openssl','pkeyutl','-decrypt','-inkey',str(d/'key.pem'),'-in',str(enc),*opts])==new.read_bytes()
secret=json.loads(k('get','secret','rac-db-password','-n','rac','-o','json'))
assert base64.b64decode(secret['data']['key.pem'])==(d/'key.pem').read_bytes()
secret['data']['pwdfile.enc']=base64.b64encode(enc.read_bytes()).decode()
run(['kubectl','replace','-f','-'],json.dumps(secret).encode())
shutil.copy2(new,d/'db-password.txt'); shutil.copy2(enc,d/'pwdfile.enc')
expected=hashlib.sha256(enc.read_bytes()).hexdigest()
for pod in ('racnode1-0','racnode2-0'):
 obj=json.loads(k('get','pod',pod,'-n','rac','-o','json'))
 vol=next(v['name'] for v in obj['spec']['volumes'] if v.get('secret',{}).get('secretName')=='rac-db-password')
 mount=next(v for v in obj['spec']['containers'][0]['volumeMounts'] if v['name']==vol)
 assert 'subPath' not in mount
 path=mount['mountPath']+'/pwdfile.enc'
 for attempt in range(36):
  actual=k('exec','-n','rac',pod,'--','sha256sum',path).decode().split()[0]
  if actual==expected: break
  time.sleep(5)
 else: raise RuntimeError('Secret projection update timed out: '+pod)
 print(pod+': encrypted credential projection verified',flush=True)
print('24-character credential encrypted, round-trip verified, saved with protected recovery backup; keys unchanged.')
PY
