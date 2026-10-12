#!/bin/bash
# Read-only scenario baseline. Does not delete/restart pods, services or nodes.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import datetime,json,pathlib,subprocess
print('Captured UTC:',datetime.datetime.now(datetime.timezone.utc).isoformat())
passwords=[p.read_text().strip() for p in (pathlib.Path.home()/'.local/share/ocne-rac-secrets').rglob('*password.txt')]
def run(args,stdin=None):
 print('\n$ '+' '.join(args))
 p=subprocess.run(args,input=stdin,capture_output=True,text=True,timeout=120)
 value=p.stdout+p.stderr
 for secret in passwords:
  if secret:value=value.replace(secret,'[REDACTED]')
 print(value,end='' if value.endswith('\n') else '\n')
 print('Exit code:',p.returncode)
 if p.returncode:raise SystemExit(p.returncode)
 return p.stdout
def obj(*args):return json.loads(subprocess.check_output(['kubectl',*args],text=True,timeout=30))
print('\nSCENARIO D: services, sessions and backup evidence before any disruptive exercise')
run(['kubectl','exec','-n','rac','racnode1-0','--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB -verbose'])
run(['kubectl','exec','-n','rac','racnode1-0','--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/srvctl config service -db RACCDB -service labpdb_app'])
run(['kubectl','exec','-n','rac','racnode1-0','--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'])
sql='''whenever sqlerror exit failure
set lines 160 pages 100
column username format a20
column service_name format a30
column log_mode format a20
select inst_id,username,service_name,status,count(*) as sessions from gv$session where type='USER' group by inst_id,username,service_name,status order by inst_id,username;
select inst_id,count(*) as active_transactions from gv$transaction group by inst_id;
select name,log_mode,open_mode from v$database;
select input_type,status,count(*) as jobs from v$rman_backup_job_details group by input_type,status;
exit
'''
run(['kubectl','exec','-i','-n','rac','racnode1-0','--','su','-','oracle','-c',"export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'"],sql)
print('\nSCENARIO E: current warnings and scheduling capacity')
run(['kubectl','-n','rac','get','events','--field-selector=type=Warning','--sort-by=.metadata.creationTimestamp'])
run(['kubectl','get','nodes','-o','custom-columns=NAME:.metadata.name,UNSCHEDULABLE:.spec.unschedulable,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory'])
print('Read-only scenario capture completed; no disruption executed.')
PY
