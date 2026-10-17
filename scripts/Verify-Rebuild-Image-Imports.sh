#!/bin/bash
# Test backup imports in a separate store; never touch CRI-O's live store.
set -euo pipefail
[[ $(id -u) == 0 && $(hostname -s) == ocne-w1 ]]
base=/scratch/rebuild-kit-20261016
[[ $(df -B1 --output=avail /scratch | tail -1) -gt 10737418240 ]]
export REBUILD_KIT_BASE="$base"
python3 <<'PY'
import pathlib,os,json,hashlib,subprocess,tarfile
base=pathlib.Path(os.environ['REBUILD_KIT_BASE'])
cmd=['podman','--root',str(base/'verify-store'),'--runroot',str(base/'verify-run'),'--storage-driver','vfs']
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest()
rows=[]
for label,tag in [('rac-slim','docker.io/roopla/oracle-rac:19.3.0-slim'),('database-operator','container-registry.oracle.com/database/operator:2.2.0')]:
 source=base/'pinned-registry'/label
 meta=json.loads((source/'source.json').read_text());raw=(source/'manifest.json').read_bytes();manifest=json.loads(raw)
 assert 'sha256:'+hashlib.sha256(raw).hexdigest()==meta['digest']
 for blob in [manifest['config'],*manifest['layers']]:
  p=source/blob['digest'].split(':')[1]
  assert p.stat().st_size==blob['size']
  assert 'sha256:'+sha(p)==blob['digest']
 subprocess.run(cmd+['pull','--quiet','dir:'+str(source)],check=True)
 ident=meta['config'].split(':')[1]
 subprocess.run(cmd+['tag',ident,tag],check=True)
 info=json.loads(subprocess.check_output(cmd+['image','inspect',ident]))[0]
 assert info['Id'].removeprefix('sha256:')==ident
 assert info['Digest']==meta['digest'],(label,info['Digest'],meta['digest'])
 pinned=tag.rsplit(':',1)[0]+'@'+meta['digest']
 result=subprocess.run(cmd+['image','exists',pinned])
 assert result.returncode==0,('Pinned reference not recognized',pinned)
 rows.append({'image':label,'config':meta['config'],'manifest':meta['digest'],'pinned_reference_recognized':True})
 print('PINNED_IMPORT_PASS',label,flush=True)
archive=base/'rac-app-images-1.0.0.tar'
assert sha(archive)=='5b137845b7afbb0ebd53ecda966c3275b2e4a76cbef8e047eb1f2e8005401145'
subprocess.run(cmd+['load','--quiet','--input',str(archive)],check=True)
with tarfile.open(archive) as tf:
 manifest=json.load(tf.extractfile('manifest.json'))
 for entry in manifest:
  ident=hashlib.sha256(tf.extractfile(entry['Config']).read()).hexdigest()
  for tag in entry['RepoTags']:
   info=json.loads(subprocess.check_output(cmd+['image','inspect',tag]))[0]
   assert info['Id'].removeprefix('sha256:')==ident
   rows.append({'image':tag,'config':'sha256:'+ident,'archive_import':True})
   print('APP_IMPORT_PASS',tag,flush=True)
(base/'image-import-verification.json').write_text(json.dumps({'store':str(base/'verify-store'),'results':rows,'containers_started':False},indent=2))
PY
chown labadmin:labadmin "$base/image-import-verification.json"
chmod 0640 "$base/image-import-verification.json"
