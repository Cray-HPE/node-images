#!/bin/bash
#
# Common file that can be sourced and then used by both
# build and runtime scripts.
#
export KUBERNETES_PULL_PREVIOUS_VERSION="1.19.9"
export KUBERNETES_PULL_VERSION="1.20.12"
export KUBE_CONTROLLER_PREVIOUS_IMAGE="cray/kube-controller-manager:v${KUBERNETES_PULL_PREVIOUS_VERSION}"
export KUBE_CONTROLLER_IMAGE="cray/kube-controller-manager:v${KUBERNETES_PULL_VERSION}"
export WEAVE_VERSION="2.8.1"
export MULTUS_VERSION="v3.7"
export CONTAINERD_VERSION="1.5.7"
export HELM_V3_VERSION="3.2.4"
export VELERO_VERSION="v1.5.2"
export ETCD_VERSION="v3.5.0"
#
# https://github.com/coredns/deployment/blob/master/kubernetes/CoreDNS-k8s_version.md
#
# coredns 1.7.0 for K8S v1.20 (move to 1.8.x for K8S v1.21)
#
export COREDNS_PREVIOUS_VERSION="1.6.7"
export COREDNS_VERSION="1.7.0"
