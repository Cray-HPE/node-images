#!/bin/bash

ceph_installed_file="/etc/cray/ceph/installed"
ceph_tuning_file="/etc/cray/ceph/tuned"
ceph_k8s_initialized_file="/etc/cray/ceph/ceph_k8s_initialized"
csi_initialized_file="/etc/cray/ceph/csi_initialized"
export KUBECONFIG=/etc/kubernetes/admin.conf
export CRAYSYS_TYPE=$(craysys type get)
if [[ $CRAYSYS_TYPE == "google" ]]; then
  registry="${1:-artifactory.algol60.net/csm-docker/stable}"
else
  registry="${1:-localhost}"
fi
CSM_RELEASE="${2:-1.5}"
CEPH_VERS="${3:-16.2.9}"

. /srv/cray/scripts/${CRAYSYS_TYPE}/lib.sh
. /srv/cray/scripts/common/wait-for-k8s-worker.sh
. /srv/cray/scripts/common/mark_step_complete.sh
. /srv/cray/scripts/common/auditing_config.sh

#
# Expand the root disk (vshasta only)
#
expand-root-disk

echo "Pre-loading ceph images"

if [[ "$CRAYSYS_TYPE" == "google" ]]
then
  /srv/cray/scripts/common/pre-load-images.sh
else
  export num_storage_nodes=$(craysys metadata get num-storage-nodes)
  echo "number of storage nodes: $num_storage_nodes"
  
  for node in $(seq 1 $num_storage_nodes); do
    if [[ "$CRAYSYS_TYPE" == "metal" ]]
    then
      nodename=$(printf "ncn-s%03d.nmn" $node)
    else
      nodename=$(printf "ncn-s%03d" $node)
    fi
    echo "Checking for node $nodename status"
    until nc -z -w 10 $nodename 22; do
      echo "Waiting for $nodename to be online, sleeping 60 seconds between polls"
      sleep 60
    done
  done
  
  for node in $(seq 1 $num_storage_nodes); do
    if [[ "$CRAYSYS_TYPE" == "metal" ]]
    then
      nodename=$(printf "ncn-s%03d.nmn" $node)
    else
      nodename=$(printf "ncn-s%03d" $node)
    fi
   ssh-keyscan -t rsa -H $nodename >> ~/.ssh/known_hosts
  done
  
  for node in $(seq 1 $num_storage_nodes); do
    if [[ "$CRAYSYS_TYPE" == "metal" ]]
    then
      nodename=$(printf "ncn-s%03d.nmn" $node)
      nodelist="${nodelist}${nodelist:+,}$nodename"
    else
      nodename=$(printf "ncn-s%03d" $node)
      nodelist="${nodelist}${nodelist:+,}$nodename"
    fi
  done
  if [[ -z $nodelist ]]
  then
    echo "nodelist is empty.  exiting..."
    exit 1
  else
    pdsh -w $nodelist /srv/cray/scripts/common/pre-load-images.sh
  fi
fi

echo "Configuring node auditing software"
configure_auditing

if [ ! -d "/etc/cray" ]; then
  mkdir /etc/cray
fi

if [ ! -d "/etc/cray/ceph" ]; then
 mkdir /etc/cray/ceph
fi

function enable_sts () {
  echo "Enabling sts for client.rgw.site1"
  ceph config set client.rgw.site1 rgw_s3_auth_use_sts true
  ceph config set client.rgw.site1 rgw_sts_key X66epaskQQrk+7B2
}

if [ -f "$ceph_installed_file" ]; then
  echo "This ceph cluster has been initialized"
else
  echo "Installing ceph"
  init
  mark_initialized $ceph_installed_file
fi

. /srv/cray/scripts/common/ceph-enable-services.sh
. /srv/cray/scripts/common/enable-ceph-mgr-modules.sh
enable_ceph_prometheus

# Redeploy ceph-grafana to pickup latest version
ceph orch daemon rm $(ceph orch ps --daemon_type grafana --format json-pretty |jq -r '.[].daemon_name')

# Make ceph read-only client for monitoring

if ! ceph auth get client.ro > /dev/null 2>&1
then
  ceph-authtool -C /etc/ceph/ceph.client.ro.keyring -n client.ro --cap mon 'allow r' --cap mds 'allow r' --cap osd 'allow r' --cap mgr 'allow r' --gen-key
  ceph auth import -i /etc/ceph/ceph.client.ro.keyring
fi

echo "Distributing the client.ro keyring"
for node in $(ceph orch host ls --format=json|jq -r '.[].hostname'); do scp /etc/ceph/ceph.client.ro.keyring $node:/etc/ceph/ceph.client.ro.keyring; done

# Wait for workers
wait_for_k8s_worker

if [ -f "$ceph_k8s_initialized_file" ]; then
  echo "This ceph radosgw config and initial k8s integration already complete"
else
  echo "Configuring ceph radosgw user/buckets and creating secrets and configmaps"
  . /etc/ansible/boto3_ansible/bin/activate
  ansible-playbook /etc/ansible/ceph-rgw-users/install.yml
  mark_initialized $ceph_k8s_initialized_file
fi

# Section for all CSI based storage

if [ -f "$csi_initialized_file" ]; then
  echo "ceph-csi configuration has been already been completed"
else
  echo "configuring ceph-csi perquisites"
  . /srv/cray/scripts/common/csi-configuration.sh

  echo "creating csi config map"
  create_ceph_csi_configmap

  echo "creating k8s storage class pre-reqs"
  create_k8s_ceph_secrets
  create_k8s_storage_class

  echo "creating cephfs storage class pre-reqs"
  create_cephfs_ceph_secrets
  create_cephfs_storage_class

  echo "creating sma storage class pre-reqs"
  create_sma_ceph_secrets
  create_sma_storage_class

  echo "creating duplicate resources for transition into dedicated namespaces"
  create_ceph_rbd_1.2_csi_configmap
  create_ceph_cephfs_1.2_csi_configmap
  create_k8s_1.2_ceph_secrets
  create_sma_1.2_ceph_secrets
  create_cephfs_1.2_ceph_secrets
  create_k8s_1.2_storage_class
  create_sma_1.2_storage_class
  create_cephfs_1.2_storage_class

  mark_initialized $csi_initialized_file
fi
