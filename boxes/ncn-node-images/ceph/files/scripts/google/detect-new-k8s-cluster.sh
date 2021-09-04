#!/bin/bash

if [[ "$(shasum $KUBECONFIG | awk '{print $1}')" != "$(cat ${KUBECONFIG}.sum)" ]]; then
  echo "Detected an updated Kubernetes cluster config, assuming a new cluster exists and we need to apply storage node resources to it"
  /usr/local/ceph/init-single-node-ceph-k8s.sh
fi
