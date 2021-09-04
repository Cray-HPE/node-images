#!/bin/bash
#
# Common file that can be sourced and then used by both
# build and runtime scripts.
#
export KUBERNETES_PULL_PREVIOUS_VERSION="v1.18.6"
export KUBERNETES_PULL_VERSION="v1.19.9"
export KUBE_CONTROLLER_PREVIOUS_IMAGE="cray/kube-controller-manager:${KUBERNETES_PULL_PREVIOUS_VERSION}"
export KUBE_CONTROLLER_IMAGE="cray/kube-controller-manager:${KUBERNETES_PULL_VERSION}"
export WEAVE_VERSION="2.8.0"
