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

function apply_multus_manifest () {
  . /srv/cray/resources/common/vars.sh

  echo "Installing Multus DaemonSet"
  envsubst < /srv/cray/resources/common/multus/multus-daemonset.yml > /etc/cray/kubernetes/multus-daemonset.yml
  kubectl apply -f /etc/cray/kubernetes/multus-daemonset.yml

  echo "Wait for initial Multus Daemonset pod to be ready..."
  kubectl rollout status daemonset kube-multus-ds-amd64 -n kube-system
}

apply_weave_manifest
apply_multus_manifest
