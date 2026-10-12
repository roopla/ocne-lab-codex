#!/bin/bash
# Recovery preparation. After copying, run Repair-RAC-Recovery-Labels.sh on
# each worker before replacing any container: cp -a retains old MCS labels.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import json,subprocess
cr=json.loads(subprocess.check_output(['kubectl','get','racdatabase','rac19c','-n','rac','-o','json']))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert cr['status']['state']=='AVAILABLE'
PY
for n in 1 2; do
 pod=racnode$n-0
 kubectl exec -i -n rac "$pod" -- bash -s <<'BACKUP_GI'
set -euo pipefail
[[ $(id -u) == 0 ]]
[[ $(findmnt -nro FSTYPE -T /u01/app/grid) == xfs ]]
[[ -s /etc/oracle/ocr.loc && -s /etc/oracle/olr.loc ]]
path=/u01/app/grid/.etcoraclebackup
[[ ! -e $path ]] || { echo 'Recovery path already exists; inspect'; exit 1; }
install -d -m 0700 -o root -g root "$path"
cp -a /etc/oracle "$path/oracle"
cmp /etc/oracle/ocr.loc "$path/oracle/ocr.loc"
cmp /etc/oracle/olr.loc "$path/oracle/olr.loc"
diff -qr /etc/oracle "$path/oracle"
stat -c '%u:%g %a %n' "$path" "$path/oracle/ocr.loc" "$path/oracle/olr.loc"
sha256sum "$path/oracle/ocr.loc" "$path/oracle/olr.loc"
BACKUP_GI
 done
kubectl exec -i -n rac racnode1-0 -- bash -s <<'RMAN_PREP'
set -euo pipefail
[[ $(findmnt -nro FSTYPE -T /u01/app/oracle) == xfs ]]
[[ $(df -B1 --output=avail /u01 | tail -1) -gt 34359738368 ]]
backup=/u01/app/oracle/recovery-backups/manual-exercises-20261011
[[ ! -e $backup ]] || { echo 'RMAN directory exists; inspect'; exit 1; }
install -d -m 0700 -o oracle -g oinstall "$backup"
cat > "$backup/backup.rman" <<'RMAN'
run {
 allocate channel c1 device type disk format '/u01/app/oracle/recovery-backups/manual-exercises-20261011/%U.bkp' maxpiecesize 8G;
 backup database plus archivelog;
 backup current controlfile;
 backup spfile;
 restore database validate;
 release channel c1;
}
list backup summary;
exit;
RMAN
chown oracle:oinstall "$backup/backup.rman"
chmod 0600 "$backup/backup.rman"
nohup su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/rman target / cmdfile=/u01/app/oracle/recovery-backups/manual-exercises-20261011/backup.rman log=/u01/app/oracle/recovery-backups/manual-exercises-20261011/rman.log; result=$?; printf "%s\n" "$result" > /u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code; exit "$result"' > "$backup/launcher.log" 2>&1 < /dev/null &
printf 'RMAN launcher PID=%s; output=%s/rman.log\n' "$!" "$backup"
RMAN_PREP
