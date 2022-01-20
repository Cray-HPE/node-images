#!/bin/bash

function apply_weave_manifest () {
  . /srv/cray/resources/common/vars.sh

  export PODS_CIDR=$(craysys metadata get kubernetes-pods-cidr)
  export WEAVE_MTU=$(craysys metadata get kubernetes-weave-mtu)

  echo "Installing/Updating Kubernetes CNI w/ pod cidr $PODS_CIDR, MTU: ${WEAVE_MTU}"
  envsubst < /srv/cray/resources/common/weave.yaml > /etc/cray/kubernetes/weave.yaml
  kubectl apply -f /etc/cray/kubernetes/weave.yaml

  echo "Wait for Weave Net to be ready..."
  kubectl rollout status daemonset weave-net -n kube-system
}

function wait_for_multus_rollout() {
  echo "Wait for Multus Daemonset rollout to complete..."
  #
  # Give the K8S ten minutes to roll through the pods
  #
  kubectl rollout status daemonset --timeout='10m' kube-multus-ds-amd64 -n kube-system > /dev/null 2>&1
  if [ "$?" -eq 0 ]; then
    echo "Multus Daemonset rollout is complete."
    return
  fi
  #
  # Rollout not done after ten minutes, let's terminate pods that are stuck
  #
  while true; do
    kubectl rollout status daemonset --timeout='1m' kube-multus-ds-amd64 -n kube-system > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      read -r pod_name pod_state < <(kubectl get pod -n kube-system -l 'app=multus' | grep Terminating | head -1l | awk '{print $1 " " $3}')
      if [ "$pod_state" == "Terminating" ]; then
        echo "Deleting $pod_name so rollout will continue..."
        kubectl delete pod -n kube-system $pod_name --force --grace-period=0 > /dev/null 2>&1
      fi
    else
      echo "Multus Daemonset rollout is complete."
      break
    fi
  done
}

function apply_multus_manifest () {
  . /srv/cray/resources/common/vars.sh

  echo "Installing Multus DaemonSet"
  envsubst < /srv/cray/resources/common/multus/multus-daemonset.yml > /etc/cray/kubernetes/multus-daemonset.yml
  kubectl apply -f /etc/cray/kubernetes/multus-daemonset.yml
  wait_for_multus_rollout
}

apply_weave_manifest
apply_multus_manifest
