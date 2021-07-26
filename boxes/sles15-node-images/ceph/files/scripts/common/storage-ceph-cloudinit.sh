#!/usr/bin/env bash

ceph_installed_file="/etc/cray/ceph/installed"
ceph_tuning_file="/etc/cray/ceph/tuned"
ceph_k8s_initialized_file="/etc/cray/ceph/ceph_k8s_initialized"
csi_initialized_file="/etc/cray/ceph/csi_initialized"
export KUBECONFIG=/etc/kubernetes/admin.conf
export CRAYSYS_TYPE=$(craysys type get)
registry="${1:-registry.local}"
CSM_RELEASE="${2:-1.5}"
CEPH_VERS="${3:-15.2.12}"

. /srv/cray/scripts/${CRAYSYS_TYPE}/lib-${CSM_RELEASE}.sh
. /srv/cray/scripts/common/wait-for-k8s-worker.sh
. /srv/cray/scripts/common/mark_step_complete.sh
. /srv/cray/scripts/common/auditing_config.sh

#
# Expand the root disk (vshasta only)
#
expand-root-disk

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
  mark_initialized $csi_initialized_file
fi
