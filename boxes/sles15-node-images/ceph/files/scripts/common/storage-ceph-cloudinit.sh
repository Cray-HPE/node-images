#!/bin/bash

ceph_installed_file="/etc/cray/ceph/installed"
ceph_tuning_file="/etc/cray/ceph/tuned"
ceph_k8s_initialized_file="/etc/cray/ceph/ceph_k8s_initialized"
csi_initialized_file="/etc/cray/ceph/csi_initialized"
export KUBECONFIG=/etc/kubernetes/admin.conf
export CRAYSYS_TYPE=$(craysys type get)
registry="${1:-registry.local}"
CSM_RELEASE="${2:-1.5}"
CEPH_VERS="${3:-15.2.8}"

. /srv/cray/scripts/${CRAYSYS_TYPE}/lib-${CSM_RELEASE}.sh
. /srv/cray/scripts/common/wait-for-k8s-worker.sh
. /srv/cray/scripts/common/mark_step_complete.sh
. /srv/cray/scripts/common/auditing_config.sh

echo "Configuring node auditing software"
configure_auditing

if [ ! -d "/etc/cray" ]; then
  mkdir /etc/cray
fi

if [ ! -d "/etc/cray/ceph" ]; then
 mkdir /etc/cray/ceph
fi

function patch_s3_bucket_function() {
  #
  # Can't find a version of ansible that includes this
  # necessary fix for creating buckets with later ceph,
  # can remove this when available.
  #
  s3_bucket_file=/usr/lib/python3.6/site-packages/ansible/modules/cloud/amazon/s3_bucket.py

cat > /tmp/s3_function.txt <<'EOF'
    try:
        current_tags = s3_client.get_bucket_tagging(Bucket=bucket_name).get('TagSet')
    except is_boto3_error_code('NoSuchTagSet'):
        return {}
    # The Ceph S3 API returns a different error code to AWS
    except is_boto3_error_code('NoSuchTagSetError'):  # pylint: disable=duplicate-except
        return {}

    return boto3_tag_list_to_ansible_dict(current_tags)


EOF

  sed -i '/def get_current_bucket_tags_dict.*/,/def paginated_list.*/!b;//!d;/def paginated_list.*/e cat /tmp/s3_function.txt' $s3_bucket_file
}

function enable_sts () {
  echo "Enabling sts for client.rgw.site1"
  ceph config set client.rgw.site1 rgw_s3_auth_use_sts true
  ceph config set client.rgw.site1 rgw_sts_key X66epaskQQrk+7B2
}

if [ -f "$ceph_installed_file" ]; then
  echo "This ceph cluster has been initialized"
else
  echo "Patching S3 Bucket function"
  patch_s3_bucket_function

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
