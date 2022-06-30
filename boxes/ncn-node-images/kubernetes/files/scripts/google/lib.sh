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

# authorized_keys goes missing.  adding this to get
# past a race condition

while grep "root" /etc/passwd  > /dev/null;
do
    sleep 1
    echo "waiting for root to disappear""
done

cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

export PROJECT_ID=$(craysys metadata get /project-id)
export NETWORK=$(craysys metadata get /network-interfaces/0/network --level node | awk -F'/' '{print $NF}')
export REGION=$(craysys metadata get region)
export DOMAIN=$(craysys metadata get domain)
export SUBNETWORK="${NETWORK}-${REGION}"
export SERVICE_ACCOUNT_KEY=$(craysys metadata get key | tr -d "\n\r")
export KUBELET_CLOUD_CONFIG_PATH="/etc/cray/kubernetes/cloud-config"
export K8S_NODE_IP=$(hostname -I | awk '{print $1}')
echo "Setting K8S_NODE_IP to ${K8S_NODE_IP} for KUBELET_EXTRA_ARGS and kubeadm config"
export KUBELET_EXTRA_ARGS="--node-ip ${K8S_NODE_IP} --cloud-provider=gce --cloud-config=${KUBELET_CLOUD_CONFIG_PATH}"
export NETWORK_DAEMONS="network"
export CONTROLLER_MANAGER_EXTRA_ARGS="{'cloud-provider': 'gce', 'cloud-config': '/etc/cray/kubernetes/cloud-config', 'configure-cloud-routes': 'false', 'flex-volume-plugin-dir': '/etc/cray/kubernetes/flexvolume'}"
export FIRST_MASTER_HOSTNAME=ncn-m001
export FIRST_STORAGE_HOSTNAME=ncn-s001
export IMAGE_REGISTRY="gcr.io/vshasta-cray"
echo "IMAGE_REGISTRY has been set to $IMAGE_REGISTRY"
export RGW_VIRTUAL_IP=""
export ETCD_HOSTNAME=$(hostname | awk -F "-" '{print $1 "-" $2}')
export ETCD_HA_PORT=2379
export CONTROL_PLANE_HOSTNAME="kubernetes-api.${DOMAIN}"
export CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_HOSTNAME}:6443"
export API_GW=api-gateway.vshasta.io
echo "API_GW has been set to $API_GW"

function get-access-token() {
  access_token=$(craysys metadata get /service-accounts/default/token --level node | \
    python3 -c 'import sys; import json; print(json.loads(sys.stdin.read())["access_token"])')
  echo $access_token
}

function pre-configure-node() {
  echo "Ensuring ${KUBELET_CLOUD_CONFIG_PATH} is in place with appropriate values"
  cat > ${KUBELET_CLOUD_CONFIG_PATH} <<EOF
[Global]
project-id = ${PROJECT_ID}
network-project-id = ${PROJECT_ID}
network-name = ${NETWORK}
subnetwork-name = ${SUBNETWORK}
node-instance-prefix = ncn-w
node-tags = worker
regional = true
multizone = true
EOF
  echo "Copying /etc/ssl/ca-bundle.pem to /etc/kubernetes/pki/oidc.pem for kube-apiserver"
  mkdir -pv /etc/kubernetes/pki
  cp /etc/ssl/ca-bundle.pem /etc/kubernetes/pki/oidc.pem
}

function configure-load-balancer-for-master() {
  systemctl enable nginx
  systemctl start nginx
  instance_group_to_join=$(craysys metadata get instance-group-to-join --level node)
  if [ ! -z "$instance_group_to_join" ]; then
    local instance_name=$(craysys metadata get /name --level node)
    local zone=$(craysys metadata get /zone --level node | sed 's:.*/::')
    local instance_url="projects/${PROJECT_ID}/zones/${zone}/instances/${instance_name}"
    cat > /tmp/add-instance.json <<EOF
{
  "instances": [{
    "instance": "${instance_url}"
  }]
}
EOF
    echo "Adding the master instance to the internal load balancer instance group: ${instance_group_to_join}"
    url="https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${zone}/instanceGroups/${instance_group_to_join}/addInstances"
    echo "POST $url"
    echo $(cat /tmp/add-instance.json)
    curl -X POST -H "Authorization: Bearer $(get-access-token)" -H "Content-Type: application/json" -d @/tmp/add-instance.json $url
  fi
}

function post-kubeadm-init() {
  echo "Ensuring proper permissions for the cloud-provider service account"
  mkdir -p /etc/cray/kubernetes/rbac
  cp /srv/cray/resources/google/rbac/cloud-provider-service-account.yaml /etc/cray/kubernetes/rbac/cloud-provider-service-account.yaml
  kubectl apply -f /etc/cray/kubernetes/rbac/cloud-provider-service-account.yaml

  echo "Installing GCE storage class"
  cp /srv/cray/resources/google/gce-storage.yaml /etc/cray/kubernetes/gce-storage.yaml
  kubectl apply -f /etc/cray/kubernetes/gce-storage.yaml

  echo "Installing GCE ingress controller"
  curl -s "http://metadata.google.internal/computeMetadata/v1/project/attributes/key" -H "Metadata-Flavor: Google" > /tmp/key.json
  export GCE_INGRESS_SECRET_NAME="gce-ingress-credentials"
  export GCE_INGRESS_CONFIGMAP_NAME="gce-ingress-config"
  kubectl -n kube-system create secret generic $GCE_INGRESS_SECRET_NAME --from-file=key.json=/tmp/key.json
  kubectl -n kube-system create configmap $GCE_INGRESS_CONFIGMAP_NAME --from-file=gce.conf=/etc/cray/kubernetes/cloud-config
  rm /tmp/key.json
  envsubst < /srv/cray/resources/google/gce-ingress/values.yaml > /etc/cray/kubernetes/gce-ingress-values.yaml
  helm install gce-ingress /srv/cray/resources/google/gce-ingress \
    --namespace kube-system -f /etc/cray/kubernetes/gce-ingress-values.yaml
}

function check-master-node() {
  master=$1
  local zone=$(craysys metadata get /zone --level node | sed 's:.*/::')
  url="https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${zone}/instances"
  curl -s -X GET -H "Authorization: Bearer $(get-access-token)" $url | cat | grep -q $master
  return $?
}

function get-etcd-initial-cluster-members() {
  result=""
  for x in `seq 3`
  do
    cnt=0
    host_name_short="ncn-m00$x"
    host_name_long="ncn-m00${x}.vshasta.io"
    check-master-node ${host_name_short}
    if [ "$?" -ne 0 ]; then
      continue
    fi
    until ! ip=$(dig +short ${host_name_long})
    do
      cnt=$((cnt+1))
      if [ "$cnt" -eq 600 ]; then
        break
      fi
      if [ "$ip" != "" ]; then
        result+="${host_name_short}=https://${ip}:2380,"
        break
      fi
      sleep 1
    done
  done
  #
  # Strip off final comma
  #
  echo $result | sed 's/.$//'
}

function get-etcdctl-backup-endpoints() {
  result=""
  for x in `seq 3`
  do
    cnt=0
    host_name_short="ncn-m00$x"
    host_name_long="ncn-m00${x}.vshasta.io"
    check-master-node ${host_name_short}
    if [ "$?" -ne 0 ]; then
      continue
    fi
    until ! ip=$(dig +short ${host_name_long})
    do
      cnt=$((cnt+1))
      if [ "$cnt" -eq 600 ]; then
        break
      fi
      if [ "$ip" != "" ]; then
        result+="${ip}:2379,"
        break
      fi
      sleep 1
    done
  done
  #
  # Strip off final comma
  #
  echo $result | sed 's/.$//'
}

function get-etcd-cluster-state() {
  echo "new"
}

function expand-root-disk() {
  echo "In expand-root-disk()"
  printf "Fix\n" | parted ---pretend-input-tty /dev/sda print
  printf "Yes\n100%%\n" | parted ---pretend-input-tty /dev/sda resizepart 2
  resize2fs /dev/sda2
}

function configure-s3fs() {
  echo "In configure-s3fs()"
}
