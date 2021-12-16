#!/usr/bin/env bash

set -e

#======================================
# Install kubectl on LiveCD
#--------------------------------------
kubectl_version="1.19.9"
echo "Installing kubectl"
curl -L https://storage.googleapis.com/kubernetes-release/release/v${kubectl_version}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
chmod a+x /usr/local/bin/kubectl