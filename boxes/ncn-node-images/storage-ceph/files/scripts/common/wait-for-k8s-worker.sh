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
