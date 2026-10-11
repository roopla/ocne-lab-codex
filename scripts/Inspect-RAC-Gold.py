"""Inspect user-built gold homes without extracting or executing them."""
from pathlib import Path, PurePosixPath
import zipfile, hashlib, json, datetime
root=Path(__file__).resolve().parents[1]
rows=[]
for name in ('oracle-dbhome-19.32.zip','oracle-gridhome-19.32.zip'):
    path=root/'ISO'/name
    before=path.stat()
    print('Checking '+name,flush=True)
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(8*1024*1024),b''): h.update(block)
    with zipfile.ZipFile(path) as z:
        entries=z.infolist()
        for e in entries:
            p=PurePosixPath(e.filename)
            if p.is_absolute() or '..' in p.parts or chr(92) in e.filename or ':' in e.filename: raise RuntimeError('Unsafe path '+e.filename)
        bad=z.testzip()
        if bad: raise RuntimeError('CRC failure '+bad)
        metadata={}
        for e in entries:
            n=e.filename
            if n.endswith(('OPatch/version.txt','OPatch/version.properties')) or ('inventory/oneoffs/' in n and n.endswith('/etc/config/inventory.xml')):
                if e.file_size<2000000: metadata[n]=z.read(e).decode('utf-8','replace')
        installers=[e.filename for e in entries if e.filename in ('runInstaller','gridSetup.sh','install/response/db_install.rsp','install/response/gridsetup.rsp')]
        patch_paths=sorted(set(e.filename.split('/')[1] for e in entries if e.filename.startswith('.patch_storage/') and len(e.filename.split('/'))>2))
        row=dict(file=name,bytes=before.st_size,sha256=h.hexdigest(),entries=len(entries),uncompressed_bytes=sum(e.file_size for e in entries),crc='passed',safe_paths=True,root_installers=installers,patch_storage=patch_paths,metadata=metadata)
    after=path.stat()
    if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns): raise RuntimeError('Archive changed')
    rows.append(row)
    print(json.dumps({k:v for k,v in row.items() if k!='metadata'}),flush=True)
(root/'logs'/'rac-gold-inventory.json').write_text(json.dumps(dict(checked_at=datetime.datetime.now().astimezone().isoformat(),archives=rows),indent=2)+'\n',encoding='utf-8')
