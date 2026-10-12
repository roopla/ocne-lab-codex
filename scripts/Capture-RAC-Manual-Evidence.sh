#!/bin/bash
# Read-only, bounded acceptance and documentation capture. No secret values printed.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import datetime,json,pathlib,subprocess,socket
password=(pathlib.Path.home()/'.local/share/ocne-rac-secrets/db-password.txt').read_text().strip()
def run(args,stdin=None):
 p=subprocess.run(args,input=stdin,text=True,capture_output=True,timeout=90)
 output=(p.stdout+p.stderr).replace(password,'[REDACTED]')
 print(output,end='' if output.endswith('\n') else '\n')
 if p.returncode: raise SystemExit(p.returncode)
 return output
print('Captured UTC:',datetime.datetime.now(datetime.timezone.utc).isoformat())
queries=[['get','nodes','-o','wide'],['-n','rac','get','racdatabases,pods,statefulsets,services,pvc','-o','wide'],['get','pv'],['-n','oracle-database-operator-system','get','pods,certificates'],['-n','cert-manager','get','deployments'],['-n','kube-system','get','daemonset','kube-multus-ds'],['-n','rac','get','statefulsets','-o','custom-columns=NAME:.metadata.name,STRATEGY:.spec.updateStrategy.type,REPLICAS:.spec.replicas']]
for args in queries:
 print('\n$ kubectl '+' '.join(args));run(['kubectl',*args])
for host,port,instance in [('192.168.77.12',31522,'RACCDB1'),('192.168.77.13',31523,'RACCDB2')]:
 with socket.create_connection((host,port),10):pass
 print(f'Control-plane TCP to {host}:{port}: PASS')
 descriptor=f'(DESCRIPTION=(CONNECT_TIMEOUT=10)(TRANSPORT_CONNECT_TIMEOUT=5)(ADDRESS=(PROTOCOL=TCP)(HOST={host})(PORT={port}))(CONNECT_DATA=(SERVICE_NAME=labpdb_app)))'
 sql=f'''whenever oserror exit failure
whenever sqlerror exit failure
connect system/"{password}"@"{descriptor}"
set pages 100 lines 200
select sys_context('USERENV','CON_NAME') as pdb,sys_context('USERENV','INSTANCE_NAME') as instance_name from dual;
declare begin
 if sys_context('USERENV','CON_NAME')<>'LABPDB' or sys_context('USERENV','INSTANCE_NAME')<>'{instance}' then raise_application_error(-20001,'Wrong PDB or instance'); end if;
end;
/
exit
'''
 print(f'Network SQL through {host}:{port}/labpdb_app (client in racnode1-0):')
 run(['kubectl','exec','-i','-n','rac','racnode1-0','--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog'],sql)
sql='''whenever sqlerror exit failure
set pages 100 lines 200
select inst_id,instance_name,status,database_status from gv$instance order by inst_id;
select inst_id,name,open_mode from gv$pdbs order by inst_id,con_id;
select inst_id,name,value from gv$parameter where name in ('sga_target','sga_max_size','pga_aggregate_target','use_large_pages') order by name,inst_id;
select inst_id,name,con_id from gv$active_services where name like 'labpdb%' order by inst_id,name;
exit
'''
print('Final SQL identity and memory verification:')
run(['kubectl','exec','-i','-n','rac','racnode1-0','--','su','-','oracle','-c',"export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'"],sql)
print('Network SQL and documentation capture completed successfully.')
PY
