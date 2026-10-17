#!/bin/bash
# Download exact installed RPM versions only; no package transactions.
set -euo pipefail
[[ $(id -u) == 0 ]]
node=$(hostname -s)
case "$node" in ocne-w1) base=/scratch/rebuild-kit-20261016;; ocne-op|ocne-cp) base=/var/tmp/rebuild-kit-20261016;; *) exit 1;; esac
install -d -m 0750 -o labadmin -g labadmin "$base"
export REBUILD_KIT_BASE="$base"
python3 <<'PY'
import dnf,pathlib,os,json,subprocess,hashlib,shutil
root=pathlib.Path(os.environ['REBUILD_KIT_BASE'])
rpms=root/'rpms';rpms.mkdir(exist_ok=True)
(root/'installed-rpms.txt').write_bytes(subprocess.check_output(['rpm','-qa','--qf','%{NAME}-%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n']))
base=dnf.Base();base.conf.read()
base.conf.cachedir=str(root/'dnf-cache');base.conf.persistdir=str(root/'dnf-persist');base.conf.logdir=str(root/'dnf-log')
base.conf.destdir=str(rpms);base.conf.keepcache=True
for name in ['dnf-cache','dnf-persist','dnf-log']:(root/name).mkdir(exist_ok=True)
base.conf.substitutions.update_from_etc('/')
base.read_all_repos();base.fill_sack()
installed=list(base.sack.query().installed());selected=[];missing=[]
for p in installed:
 if p.name=='gpg-pubkey':continue
 if os.uname().nodename.split('.')[0]=='ocne-op' and not (p.name.startswith(('olcne','oracle-ocne','kubectl')) or p.name=='conmon'):continue
 if os.uname().nodename.split('.')[0]=='ocne-cp' and p.name!='olcne-multus-chart':continue
 found=list(base.sack.query().available().filter(name=p.name,epoch=p.epoch,version=p.version,release=p.release,arch=p.arch))
 if found:selected.append(found[0])
 else:missing.append(str(p))
report={'selected_count':len(selected),'missing_exact_packages':sorted(missing),'downloaded':[]}
(root/'rpm-report.json').write_text(json.dumps(report,indent=2))
print('EXACT_RPM_SELECTION',len(selected),'MISSING',len(missing),flush=True)
for start in range(0,len(selected),40):
 batch=selected[start:start+40];base.download_packages(batch)
 for p in batch:
  path=pathlib.Path(p.localPkg())
  assert path.is_file(),str(path)
  result=subprocess.run(['rpmkeys','--checksig',str(path)],capture_output=True,text=True)
  if result.returncode or 'NOT OK' in result.stdout or 'NOKEY' in result.stdout:raise RuntimeError('RPM signature failed: '+path.name)
  h=hashlib.sha256(path.read_bytes()).hexdigest()
  if path.parent!=rpms:shutil.copy2(path,rpms/path.name)
  report['downloaded'].append({'nevra':str(p),'file':path.name,'sha256':h,'bytes':path.stat().st_size,'signature_check':'passed'})
 (root/'rpm-report.json').write_text(json.dumps(report,indent=2))
 print('EXACT_RPMS_VERIFIED',len(report['downloaded']),flush=True)
print('EXACT_RPM_EXPORT_COMPLETE',flush=True)
PY
chown -R labadmin:labadmin "$base"
chmod 0640 "$base/installed-rpms.txt" "$base/rpm-report.json"
