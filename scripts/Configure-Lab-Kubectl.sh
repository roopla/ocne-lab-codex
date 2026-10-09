set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -u) == 0 ]]
config=/home/labadmin/.kube/config
test -s /etc/kubernetes/admin.conf
install -d -m 0700 -o labadmin -g labadmin /home/labadmin/.kube
if [[ -e "$config" ]]; then cmp -s /etc/kubernetes/admin.conf "$config" || { echo 'Existing different kubeconfig; inspect'; exit 1; }; else install -m 0600 -o labadmin -g labadmin /etc/kubernetes/admin.conf "$config"; fi
profile=/home/labadmin/.bashrc
line='export KUBECONFIG=$HOME/.kube/config'
grep -qxF "$line" "$profile" || printf '\n%s\n' "$line" >> "$profile"
restorecon -RF /home/labadmin/.kube
runuser -u labadmin -- kubectl --kubeconfig "$config" get nodes -o wide
runuser -u labadmin -- kubectl --kubeconfig "$config" get deployments --all-namespaces