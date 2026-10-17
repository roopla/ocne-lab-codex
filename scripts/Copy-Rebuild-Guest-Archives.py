"""Copy large guest archives in bounded reads; verify complete SHA256 before acceptance."""
from pathlib import Path
import subprocess,hashlib,json,os
kit=Path(r'E:\OCNE19-Rebuild-Backup\kit-20261016')
ssh=['ssh','-F',r'D:\OCNE19-Lab\private\rebuild-ssh.conf','-o','BatchMode=yes']
expected={'ocne-cp':'09d278fb62691bd8153b2d7874077ef084bbdd8ca11e053d060a6919ca4359ec','ocne-w1':'b60362963ba4aeca23573ca43bbcefd7c82a172c4113f4b6643e3ab3b4198e5f','ocne-w2':'297e8690aaf590491ae6cdd2c730f500f6df3e80bcf69f274fd8812f62a1d8b9'}
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest()
for node,want in expected.items():
 base=('/var/tmp' if node=='ocne-cp' else '/scratch')+'/rebuild-kit-20261016'
 folder=kit/'images'/node;folder.mkdir(parents=True,exist_ok=True)
 dest=folder/'platform-images.tar';tmp=folder/'platform-images.chunked.partial'
 if dest.exists() and sha(dest)==want:continue
 source=base+'/platform-images.tar'
 size=int(subprocess.check_output(ssh+[node,'stat -c %s '+source],timeout=30))
 chunk=32*1024*1024
 offset=tmp.stat().st_size if tmp.exists() else 0
 assert offset<=size and (offset%chunk==0 or offset==size)
 with tmp.open('ab') as out:
  while offset<size:
   command='dd if='+source+' bs=1048576 skip='+str(offset//1048576)+' count=32 status=none'
   data=subprocess.check_output(ssh+[node,command],timeout=60)
   assert len(data)==min(chunk,size-offset),(node,offset,len(data))
   out.write(data);out.flush();offset+=len(data)
   if offset%(chunk*8)==0 or offset==size:print('COPIED',node,offset,'/',size,flush=True)
 assert sha(tmp)==want,node
 tmp.replace(dest)
 for name in ['image-inventory.json','installed-rpms.txt']:
  data=subprocess.check_output(ssh+[node,'cat '+base+'/'+name],timeout=30)
  (folder/name).write_bytes(data)
 print('ARCHIVE_COPY_VERIFIED',node,want,flush=True)
