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
echo "Checking that 00-multus.conf file is in place and not empty"
if [ -f /etc/cni/net.d/00-multus.conf ] && [ ! -s /etc/cni/net.d/00-multus.conf ]; then
  echo "Replacing zero length file 00-multus.conf "
  cp /srv/cray/resources/common/containerd/00-multus.conf /etc/cni/net.d/00-multus.conf
fi

echo "Verifying multus pod running and not in CreateContainerConfigError or CrashLoopBackOff state after reboot"
pod_state=$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -o wide -l 'app=multus'| grep $HOSTNAME | awk '{print $3}')
if [[ "$pod_state" == "CreateContainerConfigError" || "$pod_state" == "CrashLoopBackOff" ]]; then
  pod_name=$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -n kube-system -o wide -l 'app=multus'| grep $HOSTNAME | awk '{print $1}')
  echo "Restarting $pod_name"
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete pod -n kube-system $pod_name --force
fi
