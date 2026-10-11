#!/bin/bash
# Creates prerequisite secrets only. Never creates a RacDatabase.
set -euo pipefail
set +x
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
secret_dir="$HOME/.local/share/ocne-rac-secrets"
[[ ! -e $secret_dir ]]
for secret in rac-db-password rac-ssh-key; do
 existing=$(kubectl get secret -n rac "$secret" --ignore-not-found -o name)
 [[ -z $existing ]] || { echo "Secret exists: $secret; inspect before continuing."; exit 1; }
done
umask 077
install -d -m 0700 "$secret_dir"
python3 - "$secret_dir/db-password.txt" <<'PY'
import secrets,string,sys
alphabet=string.ascii_letters+string.digits
with open(sys.argv[1],'x') as target:
 target.write('Rac_' + ''.join(secrets.choice(alphabet) for _ in range(28)))
PY
openssl genrsa -out "$secret_dir/key.pem" 3072 2>/dev/null
openssl rsa -in "$secret_dir/key.pem" -out "$secret_dir/key.pub" -pubout 2>/dev/null
openssl pkeyutl -encrypt -pubin -inkey "$secret_dir/key.pub" -in "$secret_dir/db-password.txt" -out "$secret_dir/pwdfile.enc" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256
openssl pkeyutl -decrypt -inkey "$secret_dir/key.pem" -in "$secret_dir/pwdfile.enc" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256 | cmp - "$secret_dir/db-password.txt"
ssh-keygen -q -t rsa -b 4096 -N '' -C ocne-rac-lab -f "$secret_dir/id_rsa"
kubectl create secret generic rac-db-password -n rac --from-file=key.pem="$secret_dir/key.pem" --from-file=pwdfile.enc="$secret_dir/pwdfile.enc"
kubectl create secret generic rac-ssh-key -n rac --from-file=ssh-privkey="$secret_dir/id_rsa" --from-file=ssh-pubkey="$secret_dir/id_rsa.pub"
# Only names, key counts and file permissions are displayed; no secret content.
kubectl get secret -n rac rac-db-password rac-ssh-key
stat -c '%a %U %n' "$secret_dir" "$secret_dir/db-password.txt" "$secret_dir/id_rsa"
for node in ocne-w1.lab.test ocne-w2.lab.test; do
 existing=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.raccluster}')
 [[ -z $existing || $existing == raccluster01 ]]
 kubectl label node "$node" raccluster=raccluster01 --overwrite=false
done
kubectl get nodes -L raccluster
