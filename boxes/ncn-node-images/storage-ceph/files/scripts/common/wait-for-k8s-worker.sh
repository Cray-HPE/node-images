function call_kubectl() {
  output=$(kubectl "$@" 2>&1)
  rc=$?
  if [[ $rc -ne 0 ]]; then
    sleep 3
    output=$(call_kubectl "$@" 2>&1)
    echo $output >> /var/log/cloud-init-output.log
  fi
  echo "${output}"
}

function wait_for_k8s_worker() {
  echo "Waiting for at least one worker to be up and ready before we continue initialization..."
  while ! [ -f /etc/kubernetes/admin.conf ]; do
    echo "...sleeping 5 seconds until /etc/kubernetes/admin.conf appears"
    sleep 5
  done
  while ! call_kubectl get no &>/dev/null; do
    echo "...sleeping 5 seconds until kubectl get nodes succeeds"
    sleep 5
  done
  while ! call_kubectl get no | grep ncn-w | grep -e '\sReady\s' &>/dev/null; do
    echo "...sleeping 3 seconds until we have a worker"
    sleep 3
  done
  call_kubectl get nodes > /etc/cray/ceph/kubernetes_nodes.txt 2>&1
}
