#!/usr/bin/env bash

exit_code=0

export CRAYSYS_TYPE=$(craysys type get)
export KUBECONFIG=/etc/kubernetes/admin.conf

function sync-kubernetes-config() {
  local hostname="$1"
  local node_name="$2"
  if /usr/sbin/fping -c 1 $hostname &>/dev/null; then
    echo "Checking to see if the $node_name node has the most up-to-date Kubernetes config"
    master_config_sum=$(shasum $KUBECONFIG | awk '{print $1}')
    echo "First master kube config checksum: $master_config_sum"
    node_config_sum=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $hostname shasum $KUBECONFIG | awk '{print $1}')
    echo "$hostname kube config checksum: $node_config_sum"
    if [[ "$master_config_sum" != "$node_config_sum" ]]; then
      echo "Detected outdated or missing Kubernetes config on the $node_name node, attempting to update"
      (scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${KUBECONFIG} $hostname:${KUBECONFIG} && echo "UPDATED") || echo "FAILED"
    fi
  else
    echo "Unable to reach $hostname at the moment"
    exit_code=1
  fi
}

if [[ "$CRAYSYS_TYPE" == "google" ]]; then
  sync-kubernetes-config "ncn-b001" "BIS"
  sync-kubernetes-config "ncn-s001" "storage"
else
  sync-kubernetes-config "ncn-s001.nmn" "storage"
fi

exit $exit_code
