from pathlib import Path
import hashlib,json,shutil,datetime,subprocess
root=Path(r'D:\OCNE19-Lab')
backup=Path(r'E:\OCNE19-Rebuild-Backup')
kit=backup/'kit-20261016'
kit.mkdir(exist_ok=False)
(kit/'inventory').mkdir()
records=[]
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest()
def copy(source,dest):
 assert source.is_file() and not source.is_symlink(),source
 before=source.stat();dest.parent.mkdir(parents=True,exist_ok=True)
 assert not dest.exists(),dest
 shutil.copy2(source,dest)
 a,b=sha(source),sha(dest)
 assert a==b,(source,dest)
 after=source.stat();assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),source
 records.append({'source':str(source),'path':str(dest.relative_to(kit)),'bytes':before.st_size,'sha256':b})
 (kit/'inventory/local-copies.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
 print('VERIFIED',dest.relative_to(kit),before.st_size,flush=True)
vbox=r'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
info=subprocess.check_output([vbox,'showvminfo','ol9-golden','--machinereadable'],text=True)
assert 'VMState="poweroff"' in info
(kit/'inventory/golden-vminfo.txt').write_text(info,encoding='utf-8')
for p in sorted((root/'ISO').iterdir()):
 if p.is_file() and p.name!='.gitkeep':copy(p,kit/'media'/p.name)
for name in ['rac-app-images-1.0.0.tar','rac-app-source-1.0.0.tar.gz']:
 copy(root/'private'/name,kit/'images'/name)
for name in ['golden-credential.clixml','labadmin-credential.clixml','ssh-endpoints.json','windows_known_hosts','workstation_ed25519','workstation_ed25519.pub']:
 copy(root/'private'/name,kit/'protected-access'/name)
for p in (root/'private/rac-app-secrets').rglob('*'):
 if p.is_file():copy(p,kit/'protected-access/rac-app-secrets'/p.relative_to(root/'private/rac-app-secrets'))
copy(Path(r'D:\VMs\ol9-golden\ol9-golden.vdi'),kit/'golden/base/ol9-golden.vdi')
golden=Path(r'C:\Users\pradeep reddy\VirtualBox VMs\ol9-golden')
for p in golden.rglob('*'):
 if p.is_file():copy(p,kit/'golden/config-and-snapshots'/p.relative_to(golden))
info2=subprocess.check_output([vbox,'showvminfo','ol9-golden','--machinereadable'],text=True)
assert info2==info,'Golden VM configuration changed during copy'
for vm in ['ocne-op','ocne-cp','ocne-w1','ocne-w2']:
 data=subprocess.check_output([vbox,'showvminfo',vm,'--machinereadable'],text=True)
 (kit/'inventory'/f'{vm}-vminfo.txt').write_text(data,encoding='utf-8')
print('LOCAL COPY COMPLETE',len(records),'files',sum(r['bytes'] for r in records),'bytes',flush=True)
