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
etcdctl_backup_endpoints=$1
http_s3_endpoint=$2

echo "Creating cert secret for baremetal etcd backups"
kubectl --namespace=kube-system create secret generic kube-etcdbackup-etcd --from-file=/etc/kubernetes/pki/etcd/ca.crt --from-file=tls.crt=/etc/kubernetes/pki/etcd/server.crt --from-file=tls.key=/etc/kubernetes/pki/etcd/server.key --save-config --dry-run=client -o yaml | kubectl apply -f -

until kubectl get secret etcd-backup-s3-credentials > /dev/null  2>&1
do
  sleep 5
  echo "Waiting for storage node to create etcd-backup-s3-credentials secret..."
done

access_key=$(kubectl get secret etcd-backup-s3-credentials -o json | jq -r '.data.access_key' | base64 -d)
secret_key=$(kubectl get secret etcd-backup-s3-credentials -o json | jq -r '.data.secret_key' | base64 -d)

#
# If we don't have a vip to hit from metadata, let's
# pull the endpoint from the secret.
#
if [[ "$http_s3_endpoint" == "" ]]; then
  http_s3_endpoint=$(kubectl get secret etcd-backup-s3-credentials -o json | jq -r '.data.http_s3_endpoint' | base64 -d)
fi

echo "Creating s3 secret for baremetal etcd backups"
kubectl --namespace=kube-system create secret generic kube-etcdbackup-s3 --from-literal=S3_ACCESS_KEY=$access_key --from-literal=S3_SECRET_KEY=$secret_key --save-config --dry-run=client -o yaml | kubectl apply -f -

cat > /tmp/kube-etcdbackup-cm.yaml <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-etcdbackup
  namespace: kube-system
data:
  ETCDCTL_ENDPOINTS: $etcdctl_backup_endpoints
  ETCDCTL_CACERT: /ssl/ca.crt
  ETCDCTL_CERT: /ssl/tls.crt
  ETCDCTL_KEY: /ssl/tls.key
  S3_ALIAS: backup-minio
  S3_BUCKET: etcd-backup
  S3_ENDPOINT: $http_s3_endpoint
  S3_FOLDER: bare-metal
  AUTOCLEAN: "1"
EOF

echo "Creating/modifying configmap for baremetal etcd backups"
output=$(kubectl -n kube-system apply -f /tmp/kube-etcdbackup-cm.yaml 2>&1)
rc=$?
if [[ $rc -eq 1 ]] && [[ "$output" == *"AlreadyExists"* ]]; then
  echo "Configmap for etcd backups already created by another master node"
else
  echo "Configmap for etcd backups successfully created or updated"
fi
