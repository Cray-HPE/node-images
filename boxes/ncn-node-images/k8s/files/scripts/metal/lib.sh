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

  cmngw=$(craysys metadata get --level node ipam | jq .cmn.gateway | tr -d '"')
  if ! ip route replace default via ${cmngw} dev bond0.can0; then
    echo "Replacing default route via '$cmngw' on device bond0.can0 failed"
  fi
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
