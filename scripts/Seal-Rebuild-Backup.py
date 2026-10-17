"""Capture reviewed source/Git history and seal the approved rebuild kit with hashes.
Run after Verify-Rebuild-Backup.py and documentation checks succeed.
"""
from pathlib import Path
import hashlib,json,subprocess,shutil,datetime
root=Path(r'D:\OCNE19-Lab');kit=Path(r'E:\OCNE19-Rebuild-Backup\kit-20261016')
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest()
assert (kit/'inventory/verification.json').is_file()
assert not list(kit.rglob('*.partial')),'Incomplete files remain'
source=kit/'source';source.mkdir(exist_ok=False)
tracked=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
extras=['docs/REBUILD-READINESS.md','docs/REBUILD-BACKUP.md','scripts/Export-Rebuild-Guest-Kit.sh','scripts/Inspect-Rebuild-Kit-Sources.sh','scripts/Prepare-Rebuild-Local-Backup.py','scripts/Preserve-Pinned-Rebuild-Images.py','scripts/Test-Rebuild-Image-Export.sh','scripts/Preserve-Rebuild-RPMs.sh','scripts/Verify-Rebuild-Image-Imports.sh','scripts/Copy-Rebuild-Guest-Archives.py','scripts/Verify-Rebuild-Backup.py','scripts/Seal-Rebuild-Backup.py']
records=[]
for name in sorted(set([p for p in tracked if p]+extras)):
 p=root/name
 assert p.is_file() and not p.is_symlink(),name
 assert p.resolve().is_relative_to(root)
 if name.split('/')[0] in ['private','ISO','logs','vms']:assert p.name=='.gitkeep',name
 dest=source/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
 digest=sha(p);assert sha(dest)==digest,name
 records.append({'path':name,'bytes':p.stat().st_size,'sha256':digest})
state={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'branch':subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip(),'working_tree_status':subprocess.check_output(['git','status','--short'],cwd=root,text=True),'files':records}
(kit/'inventory/source-snapshot.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
bundle=kit/'repository.bundle';assert not bundle.exists()
subprocess.run(['git','bundle','create',str(bundle),'--all'],cwd=root,check=True)
subprocess.run(['git','bundle','verify',str(bundle)],cwd=root,check=True)
print('SOURCE_AND_GIT_VERIFIED',len(records),'files',state['head'],flush=True)
# Confirm the original source VM remains powered off with its captured configuration.
vbox=r'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
info=subprocess.check_output([vbox,'showvminfo','ol9-golden','--machinereadable'],text=True)
assert info==(kit/'inventory/golden-vminfo.txt').read_text(encoding='utf-8')
assert 'VMState="poweroff"' in info
manifest=[]
for p in sorted(kit.rglob('*')):
 if not p.is_file():continue
 relative=p.relative_to(kit).as_posix()
 if relative in ['inventory/SHA256.json','BACKUP-RECEIPT.txt']:continue
 assert not p.is_symlink()
 manifest.append({'path':relative,'bytes':p.stat().st_size,'sha256':sha(p)})
 if len(manifest)%300==0:print('MANIFEST_HASHED',len(manifest),flush=True)
manifest_path=kit/'inventory/SHA256.json'
manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Compare the sealed hashes with earlier accepted copies, not just the current files.
index={r['path']:r for r in manifest}
for r in json.loads((kit/'inventory/local-copies.json').read_text()):
 assert index[r['path'].replace('\\','/')]['sha256']==r['sha256']
for r in records:assert index['source/'+r['path']]['sha256']==r['sha256']
for node in ['ocne-op','ocne-cp','ocne-w1']:
 for r in json.loads((kit/'packages'/node/'rpm-report.json').read_text())['downloaded']:
  assert index['packages/'+node+'/rpms/'+r['file']]['sha256']==r['sha256']
for r in json.loads((kit/'inventory/verification.json').read_text())['platform_archives']:
 assert index['images/'+r['node']+'/platform-images.tar']['sha256']==r['sha256']
for label in ['rac-slim','database-operator']:
 folder=kit/'images/pinned-registry'/label
 meta=json.loads((folder/'source.json').read_text());m=json.loads((folder/'manifest.json').read_text())
 prefix='images/pinned-registry/'+label+'/'
 assert index[prefix+'manifest.json']['sha256']==meta['digest'].split(':')[1]
 for blob in [m['config'],*m['layers']]:
  digest=blob['digest'].split(':')[1]
  assert index[prefix+digest]['sha256']==digest
receipt={'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files_in_manifest':len(manifest),'bytes_in_manifest':sum(r['bytes'] for r in manifest),'manifest_sha256':sha(manifest_path),'git_head':state['head'],'source_snapshot_files':len(records),'golden_configuration_unchanged':True,'database_application_data_preserved':False,'destruction_performed':False,'limits':['Golden restore and clean rebuild not rehearsed','Inactive UEK8 RPMs unavailable; see package coverage','No offline installation/dependency-resolution acceptance','Known GI image restart limitation retained']}
(kit/'BACKUP-RECEIPT.txt').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('BACKUP_SEALED',json.dumps(receipt),flush=True)
