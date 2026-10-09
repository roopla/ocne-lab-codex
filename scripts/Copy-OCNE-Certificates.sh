set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 ]]
find /home/labadmin/certificates -maxdepth 2 -type f -printf '%m %u:%g %p\n'
cd /home/labadmin
olcnectl certificates copy --cert-dir /home/labadmin/certificates --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test --ssh-identity-file /home/labadmin/.ssh/id_rsa --ssh-login-name root --remote-command 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/labadmin/.ssh/known_hosts'