#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
#
# Common file that can be sourced and then used by both
# build and runtime scripts.
#
export KUBERNETES_PULL_PREVIOUS_VERSION="1.20.13"
export KUBERNETES_PULL_VERSION="$(rpm -q --queryformat '%{VERSION}' kubeadm | awk -F '.' '{print $1"."$2"."$3}')"
export WEAVE_VERSION="2.8.1"
export WEAVE_PREVIOUS_VERSION="2.8.0"
export MULTUS_VERSION="v3.7"
export MULTUS_PREVIOUS_VERSION="v3.1"
export CONTAINERD_VERSION="1.5.12"
export HELM_V3_VERSION="3.2.4"
export VELERO_VERSION="v1.5.2"
export ETCD_VERSION="v3.5.0"
export PAUSE_VERSION="3.4.1"
export KATA_VERSION="2.4.3"
#
# https://github.com/coredns/deployment/blob/master/kubernetes/CoreDNS-k8s_version.md
#
# coredns 1.7.0 for K8S v1.20 (move to 1.8.x for K8S v1.21)
#
export COREDNS_PREVIOUS_VERSION="1.7.0"
export COREDNS_VERSION="v1.8.0"

# adding troubleshooting echo
echo "COREDNS_VERSION=$COREDNS_VERSION"
