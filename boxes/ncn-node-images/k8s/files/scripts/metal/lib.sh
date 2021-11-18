#!/bin/bash

ip=$(dig +short $(hostname).nmn)
cnt=0

while [ "$ip" == "" ]; do
  cnt=$((cnt+1))
  ip=$(dig +short $(hostname).nmn)
  echo "Waiting for resolution of $(hostname)"
  sleep 1
  if [ "$cnt" -eq 60 ]; then
    echo "ERROR: Giving up on DNS resolution..."
    exit 1
  fi
done

export NETWORK_DAEMONS=""
export RGW_VIRTUAL_IP="http://$(craysys metadata get rgw-virtual-ip)"
export CONTROLLER_MANAGER_EXTRA_ARGS="{'flex-volume-plugin-dir': '/etc/cray/kubernetes/flexvolume'}"
export CONTROL_PLANE_HOSTNAME="$(craysys metadata get k8s_virtual_ip)"
echo "CONTROL_PLANE_HOSTNAME has been set to $CONTROL_PLANE_HOSTNAME"
export CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_HOSTNAME}:6442"
echo "CONTROL_PLANE_ENDPOINT has been set to $CONTROL_PLANE_ENDPOINT"
export K8S_NODE_IP="$(dig +short $(hostname).nmn)"
echo "Setting K8S_NODE_IP to ${K8S_NODE_IP} for KUBELET_EXTRA_ARGS and kubeadm config"
export KUBELET_EXTRA_ARGS="--node-ip ${K8S_NODE_IP}"
export FIRST_MASTER_HOSTNAME=$(craysys metadata get first_master_hostname)
echo "FIRST_MASTER_HOSTNAME has been set to $FIRST_MASTER_HOSTNAME"
export IMAGE_REGISTRY="docker.io"
echo "IMAGE_REGISTRY has been set to $IMAGE_REGISTRY"
export FIRST_STORAGE_HOSTNAME=ncn-s001.nmn
export ETCD_HOSTNAME=$(hostname)
export ETCD_HA_PORT=2381

function get_ip_from_metadata() {
  host=$1
  ip=$(cloud-init query ds | jq -r ".meta_data[].host_records[] | select(.aliases[]? == \"$host\") | .ip" 2>/dev/null)
  echo $ip
}

function pre-configure-node() {
  echo "In pre-configure-node()"
  # placeholder; nothing todo right now, remove this note if/when code is
  # added.
  return 0
}

function configure-load-balancer-for-master() {
  echo "In configure-load-balancer-for-master()"

  if [[ "$(hostname)" =~ ^ncn-m ]]; then
    echo "Configuring haproxy and keepalived"
    /srv/cray/scripts/metal/generate_haproxy_cfg.sh > /etc/haproxy/haproxy.cfg
    /srv/cray/scripts/metal/generate_keepalived_conf.sh > /etc/keepalived/keepalived.conf

    for service in haproxy keepalived; do
      systemctl enable $service
      systemctl start $service
    done
  fi
}

function post-kubeadm-init() {
  echo "In post-kubeadm-init()"
}

function get-etcd-initial-cluster-members() {
  result=""
  for x in `seq 5`
  do
    host_name="ncn-m00$x.nmn"
    host_name_short="ncn-m00$x"
    ip=$(get_ip_from_metadata $host_name)
    if [ "$ip" != "" ]; then
      result+="${host_name_short}=https://${ip}:2380,"
    fi
  done
  #
  # Strip off final comma
  #
  echo $result | sed 's/.$//'
}

function get-etcdctl-backup-endpoints() {
  result=""
  for x in `seq 5`
  do
    host_name="ncn-m00$x.nmn"
    ip=$(get_ip_from_metadata $host_name)
    if [ "$ip" != "" ]; then
      result+="${ip}:2379,"
    fi
  done
  #
  # Strip off final comma
  #
  echo $result | sed 's/.$//'
}

function get-etcd-cluster-state() {
  me=$(get_ip_from_metadata $(hostname).nmn)
  for x in `seq 5`
  do
    host_name="ncn-m00$x.nmn"
    host_name_short="ncn-m00$x"
    ip=$(get_ip_from_metadata $host_name)
    if [ "$ip" != "" ]; then
      if [ "$me" != "$ip" ]; then
        member_list=$(etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/ca.crt  --key=/etc/kubernetes/pki/etcd/ca.key --endpoints=https://${ip}:2379 member list 2>&1)
        rc=$?
        if [ "$rc" -eq 0 ]; then
          echo $member_list | grep -q "unstarted.*$me"
          rc=$?
          if [ "$rc" -eq 0 ]; then
             #
             # We are being added to an existing cluster
             #
             echo "existing"
             return
          fi
        fi
      fi
    fi
  done
  echo "new"
}

function expand-root-disk() {
  echo "In expand-root-disk() -- skipping since we're on metal"
}

function configure-s3fs-directory() {
  echo "In configure-s3fs-directory()"

  s3fs_cache_dir=/var/lib/s3fs_cache

  if [ -d ${s3fs_cache_dir} ]; then
    s3fs_opts="use_path_request_style,use_cache=${s3fs_cache_dir},check_cache_dir_exist=true"
   else
    s3fs_opts="use_path_request_style"
  fi

  if [[ "$(hostname)" =~ ^ncn-m ]]; then
    s3_user=sds
    s3_bucket=sds
    s3fs_mount_dir=/var/lib/sdu
  else
    s3_user=ims
    s3_bucket=boot-images
    s3fs_mount_dir=/var/lib/cps-local
  fi

  echo "Configuring for ${s3_bucket} S3 bucket at ${s3fs_mount_dir} for ${s3_user} S3 user"

  mkdir -p ${s3fs_mount_dir}
  pwd_file=/root/.${s3_user}.s3fs
  access_key=$(kubectl get secret ${s3_user}-s3-credentials -o json | jq -r '.data.access_key' | base64 -d)
  secret_key=$(kubectl get secret ${s3_user}-s3-credentials -o json | jq -r '.data.secret_key' | base64 -d)
  s3_endpoint=$(kubectl get secret ${s3_user}-s3-credentials -o json | jq -r '.data.http_s3_endpoint' | base64 -d)

  echo "${access_key}:${secret_key}" > ${pwd_file}
  chmod 600 ${pwd_file}

  if ! mount | grep -q ^s3fs.*${s3fs_mount_dir}; then
    s3fs ${s3_bucket} ${s3fs_mount_dir} -o passwd_file=${pwd_file},url=${s3_endpoint},${s3fs_opts}
  fi

  if ! grep -q ^${s3_bucket} /etc/fstab; then
    echo "Adding fstab entry for ${s3_bucket} S3 bucket at ${s3fs_mount_dir} for ${s3_user} S3 user"
    echo "${s3_bucket} ${s3fs_mount_dir} fuse.s3fs _netdev,allow_other,passwd_file=${pwd_file},url=${s3_endpoint},${s3fs_opts} 0 0" >> /etc/fstab
  fi

}
