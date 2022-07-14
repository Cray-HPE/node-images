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

export KUBECONFIG=/etc/kubernetes/admin.conf

if kubectl get secret -n istio-system ingress-gateway-cert > /dev/null 2>&1 ; then
  kubectl get secret -n istio-system ingress-gateway-cert -o json | jq -r '.data."ca.crt"' | base64 -d > /tmp/oidc.pem
  fs_sha=$(shasum /etc/kubernetes/pki/oidc.pem | awk '{print $1}')
  k8s_sha=$(shasum /tmp/oidc.pem | awk '{print $1}')
  if [ "$k8s_sha" != "$fs_sha" ]; then
    echo "Detected outdated or missing oidc.pem file -- refreshing with ingress-gateway-cert secret contents..."
    mv /tmp/oidc.pem /etc/kubernetes/pki/oidc.pem
  else
    rm /tmp/oidc.pem
    echo "Verified filesystem oidc.pem matches ingress-gateway-cert secret..."
  fi
else
  echo "ingress-gateway-cert secret not available yet, nothing to do..."
fi
