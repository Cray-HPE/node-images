#!/bin/bash

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
