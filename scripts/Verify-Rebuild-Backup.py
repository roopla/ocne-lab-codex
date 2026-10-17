"""Verify approved rebuild copies and capture source/Git state; no lab mutations.
Run only after all export/copy jobs finish. Existing source snapshot is never overwritten.
"""
from pathlib import Path
import hashlib,json,subprocess,tarfile,shutil,datetime
ROOT=Path(r'D:\OCNE19-Lab')
KIT=Path(r'E:\OCNE19-Rebuild-Backup\kit-20261016')
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(8*1024*1024),b''):h.update(chunk)
 return h.hexdigest()
expected={'ocne-cp':'09d278fb62691bd8153b2d7874077ef084bbdd8ca11e053d060a6919ca4359ec','ocne-w1':'b60362963ba4aeca23573ca43bbcefd7c82a172c4113f4b6643e3ab3b4198e5f','ocne-w2':'297e8690aaf590491ae6cdd2c730f500f6df3e80bcf69f274fd8812f62a1d8b9'}
archive_results=[]
for node,want in expected.items():
 folder=KIT/'images'/node;archive=folder/'platform-images.tar'
 assert sha(archive)==want,node
 inventory=json.loads((folder/'image-inventory.json').read_text())
 with tarfile.open(archive) as tf:
  entries=json.load(tf.extractfile('manifest.json'));ids=[]
  for entry in entries:
   config=hashlib.sha256(tf.extractfile(entry['Config']).read()).hexdigest();ids.append(config)
   assert any(i['Id'].removeprefix('sha256:')==config for i in inventory)
   for layer in entry['Layers']:assert tf.getmember(layer).isfile()
  for item in inventory:
   names=item['Names'] or []
   if any(n.startswith(('container-registry.oracle.com/','quay.io/jetstack/','docker.io/roopla/oracle-rac','docker.io/library/busybox')) for n in names):assert item['Id'].removeprefix('sha256:') in ids
 archive_results.append({'node':node,'images':len(ids),'sha256':want})
 print('PLATFORM_ARCHIVE_VERIFIED',node,len(ids),flush=True)
packages={};package_results=[]
for node in ['ocne-op','ocne-cp','ocne-w1']:
 folder=KIT/'packages'/node;report=json.loads((folder/'rpm-report.json').read_text())
 assert len(report['downloaded'])==report['selected_count']
 for item in report['downloaded']:
  p=folder/'rpms'/item['file'];assert p.stat().st_size==item['bytes'] and sha(p)==item['sha256']
  packages[item['nevra']]=item
 package_results.append({'node':node,'verified':len(report['downloaded']),'unavailable':report['missing_exact_packages']})
 print('RPM_COPIES_VERIFIED',node,len(report['downloaded']),flush=True)
coverage={}
for node in ['ocne-op','ocne-cp','ocne-w1','ocne-w2']:
 folder=KIT/('packages' if node=='ocne-op' else 'images')/node
 wanted=(folder/'installed-rpms.txt').read_text().splitlines()
 missing=[p for p in wanted if not p.startswith('gpg-pubkey-') and p.replace('-0:','-') not in packages]
 assert len(missing)==8 and all(p.startswith('kernel-uek') and '6.12.0-203.76.7.3.el9uek' in p for p in missing),(node,missing)
 assert any(p.startswith('kernel-uek-0:5.15.0-324.217.5.3.el9uek') for p in wanted),node
 coverage[node]=sorted(missing)
print('PACKAGE_COVERAGE_GAPS',json.dumps({n:len(p) for n,p in coverage.items()}),flush=True)
(KIT/'inventory/package-coverage.json').write_text(json.dumps(coverage,indent=2))
imports=json.loads((KIT/'inventory/image-import-verification.json').read_text())
assert len(imports['results'])==6
summary={'verified_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'platform_archives':archive_results,'rpm_exports':package_results,'package_coverage_gaps':coverage,'isolated_image_imports':imports,'database_data_preserved':False,'clean_rebuild_rehearsed':False,'golden_restore_rehearsed':False}
(KIT/'inventory/verification.json').write_text(json.dumps(summary,indent=2))
print('KIT_CONTENT_VERIFICATION_COMPLETE',flush=True)
