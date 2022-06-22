#!/bin/bash

function wait_for_health_ok() {
  cnt=0
  while true; do
    if [[ "$cnt" -eq 360 ]]; then
      echo "ERROR: Giving up on waiting for ceph to become healthy..."
      break
    fi
    output=$(ceph -s | grep -q HEALTH_OK)
    if [[ "$?" -eq 0 ]]; then
      echo "Ceph is healthy -- continuing..."
      break
    fi
    sleep 5
    echo "Sleeping for five seconds waiting ceph to be healthy..."
    cnt=$((cnt+1))
  done
}

function prepare_hosts() {
  num_storage_nodes=1
  for node in $(seq 1 $num_storage_nodes); do
    nodename=$(printf "ncn-s%03d" $node)
    echo "Calling cephadm prepare-host for $nodename..."
    ceph cephadm prepare-host $nodename
  done
}

function wait_for_osds() {
  num_storage_nodes=1
  cnt=0
  while true; do
    if [[ "$cnt" -eq 60 ]]; then
      echo "ERROR: Giving up on waiting for osds to come up after thirty minutes..."
      break
    fi
    current_num=$(ceph node ls| jq -r '.osd|keys[]' | wc -l)
    if [[ "$current_num" -eq "$num_storage_nodes" ]]; then
      echo "There are $current_num osd nodes -- continuing..."
      break
    fi
    echo "Sleeping for five seconds waiting for osds to come up..."
    sleep 30
    ceph mgr fail $(ceph mgr dump | jq -r .active_name)
    cephadm ls > /etc/cray/ceph/cephadm_output.txt 2>&1
    cnt=$((cnt+1))
  done
}

function check_for_duplicate_mgr() {
  echo "Checking for duplicate mgr daemons on ncn-s001"
  num_mgrs_on_one=$(ceph orch ps --daemon-type mgr -f json-pretty | jq -r '.[].hostname' | grep ncn-s001 | wc -l)
  if [[ "$num_mgrs_on_one" -gt 1  ]]; then
    active_mgr=$(ceph mgr dump | jq -r .active_name)
    echo "Fail over the active mgr"
    ceph mgr fail $active_mgr
    echo "Killing duplicate manager daemon mgr.${active_mgr}"
    ceph orch daemon rm mgr.${active_mgr} || echo "Non zero return code when killing duplicate daemon"
  fi
}

function restart_daemons_by_type() {
  daemon_type=$1
  output=$(ceph orch ps --daemon-type $daemon_type -f json-pretty | jq -r '.[] | select(.status_desc=="running") | .daemon_id')
  for daemon in $output; do
    echo "Restarting ${daemon_type}.${daemon}"
    output=$(ceph orch daemon restart ${daemon_type}.${daemon})
    echo $output
    echo "Sleeping 10 seconds between daemons"
    sleep 10
  done
}

function redeploy_osd_daemons() {
  output=$(ceph orch ps --daemon-type osd -f json-pretty | jq -r '.[] | select(.status_desc=="running") | .daemon_id')
  for daemon in $output; do
    echo "Restarting osd.${daemon}"
    output=$(ceph orch daemon restart osd.${daemon})
    echo $output
    echo "Sleeping 10 seconds between daemons"
    sleep 10
  done
}

function wait_for_running_daemons() {
  daemon_type=$1
  num_daemons=$2
  cnt=0
  while true; do
    if [[ "$cnt" -eq 60 ]]; then
      echo "ERROR: Giving up on waiting for $num_daemons $daemon_type daemons to be running..."
      break
    fi
    output=$(ceph orch ps --daemon-type $daemon_type -f json-pretty | jq -r '.[] | select(.status_desc=="running") | .daemon_id')
    if [[ "$?" -eq 0 ]]; then
      num_active=$(echo "$output" | wc -l)
      if [[ "$num_active" -eq $num_daemons ]]; then
        echo "Found $num_daemons running $daemon_type daemons -- continuing..."
        break
      fi
    fi
    sleep 5
    echo "Sleeping for five seconds waiting for $num_daemons running $daemon_type daemons..."
    cnt=$((cnt+1))
  done
}


function init() {

  if [[ -f /root/zero.file ]]; then rm /root/zero.file; fi

  # Change into the /srv/cray/tmp directory to keep trash out of the / dir
  pushd /srv/cray/tmp

  first_master_hostname=ncn-m001

  echo "Waiting for general DNS/networking to be operating as expected, for our first master node to be available..."
  while host $first_master_hostname | grep 'NXDOMAIN' &>/dev/null; do
    sleep 5
  done

  ssh-keyscan -t rsa -H $(hostname) >> ~/.ssh/known_hosts
  ssh-keyscan -t rsa -H ncn-s001 >> ~/.ssh/known_hosts
  ssh-keyscan -t rsa -H  $(ip -4 -br  address show dev eth0 |awk '{split($3,ip,"/"); print ip[1]}')>> ~/.ssh/known_hosts

  #
  # Enable CEPH repos as described at http://ceph.com/docs/master/install/get-packages/#rpm
  # Install ceph-deploy package
  #
  export DATA_DEV=/dev/sdb
  export FS_TYPE=xfs
  export CEPH_RELEASE=nautilus

  # if you need to install CEPH packages
  #ceph-deploy install --release ${CEPH_RELEASE} $HOSTNAME

  # Create your initial files for cluster creation
  cephadm --retry 60 --image artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v$CEPH_VERS bootstrap --single-host-defaults --skip-monitoring-stack --skip-mon-network --skip-pull --skip-dashboard --mon-ip $(ip -4 -br  address show dev eth0 |awk '{split($3,ip,"/"); print ip[1]}')

  ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(hostname)
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@ncn-s001
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(ip -4 -br  address show dev eth0 |awk '{split($3,ip,"/"); print ip[1]}')

  # Add in the options that allow this to run as a single node cluster
  # Add default image features to allow volume mapping

  ceph config set osd osd_pool_default_size 1
  ceph config set client.osd osd_pool_default_size 1
  ceph config set global osd_pool_default_size 1
  ceph config set osd osd_crush_chooseleaf_type 0
  ceph config set osd rbd_default_features 3
  ceph config set global mon_max_pg_per_osd 700

  # Deploy mgr and create your OSD
  while [[ $avail != "true" ]] && [[ $backend != "cephadm" ]]
  do
    backend=$(ceph orch status -f json-pretty|jq -r .backend)
    avail=$(ceph orch status -f json-pretty|jq .available)
    if [[ $avail != "true" ]]
    then
      ceph mgr module enable cephadm
    fi
    if [[ $backend != "cephadm" ]]
    then
      ceph orch set backend cephadm
    fi
  done
  ceph orch host label add $(hostname) _admin
  ceph orch apply mgr --placement=1

  echo "Running ceph orch apply osd"
  ceph orch apply osd --all-available-devices

  echo "Sleeping for 30 seconds to let osds settle"
  sleep 30

  wait_for_osds

  echo "Container image values"
  ceph config set mgr mgr/cephadm/container_image_grafana       "$registry/quay.io/ceph/ceph-grafana:8.3.5"
  ceph config set mgr mgr/cephadm/container_image_prometheus    "$registry/prometheus/prometheus:v2.18.1"
  ceph config set mgr mgr/cephadm/container_image_alertmanager  "$registry/quay.io/prometheus/alertmanager:v0.21.0"
  ceph config set mgr mgr/cephadm/container_image_node_exporter "$registry/quay.io/prometheus/node-exporter:v1.2.2"

  echo "Dashboard and monitoring images values set"

  echo "Deploying alertmanager, grafana, node-exporter and prometheus"
  ceph orch apply alertmanager
  ceph orch apply grafana
  ceph orch apply node-exporter
  ceph orch apply prometheus

  enable_sts

  ceph cephadm generate-key
  ceph cephadm get-pub-key > /etc/ceph/ceph.pub
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(hostname)
  ssh-keyscan -t rsa -H $(hostname) >> ~/.ssh/known_hosts

  # Create pools and set the applications
  ceph osd pool create kube 1 1
  ceph osd pool create cephfs.cephfs.data 1 1
  ceph osd pool create cephfs.cephfs.meta 1 1
  ceph osd pool create default.rgw.buckets.data 1 1
  ceph osd pool create default.rgw.control 1 1
  ceph osd pool create default.rgw.buckets.index 1 1
  ceph osd pool create default.rgw.meta 1 1
  ceph osd pool create default.rgw.log 1 1
  ceph osd pool application enable kube rbd
  ceph osd pool application enable default.rgw.buckets.data rgw
  ceph osd pool application enable default.rgw.control rgw
  ceph osd pool application enable default.rgw.buckets.index rgw
  ceph osd pool application enable default.rgw.meta rgw
  ceph osd pool application enable default.rgw.log rgw
  ceph osd pool application enable cephfs.cephfs.data cephfs
  ceph osd pool application enable cephfs.cephfs.metadata cephfs
  rbd pool init kube
  ceph health mute POOL_NO_REDUNDANCY --sticky
  ceph osd pool set device_health_metrics size 1

  wait_for_health_ok

  cp /etc/ceph/ceph.pub ~/.ssh/ceph.pub
  ceph cephadm get-ssh-config > ~/.ssh/ssh_config
  ceph config-key get mgr/cephadm/ssh_identity_key > ~/.ssh/cephadm_private_key
  chmod 0600 ~/.ssh/cephadm_private_key
  cp /etc/ceph/ceph.pub ~/ceph.pub
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(hostname)
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@ncn-s001
  ssh-copy-id -f -i /etc/ceph/ceph.pub root@$(ip -4 -br  address show dev eth0 |awk '{split($3,ip,"/"); print ip[1]}')

  # Deploy ceph mds and create base cephfs share
  echo "Creating placement group for cephfs"
   ceph fs volume create cephfs --placement="1 $HOSTNAME"

   echo "Sleeping for 30 seconds to let cephfs get going before checking health"
   sleep 30
   wait_for_health_ok

   echo "Setting cephfs allow_standby_replay true"
   ceph fs set cephfs allow_standby_replay true

   echo "Setting cephfs max_mds to 1"
   ceph fs set cephfs max_mds 1

   echo "Setting cephfs standby_count_wanted to 0"
   ceph fs set cephfs standby_count_wanted 0

   ceph orch apply rgw site1 zone1 --placement="1 $(ceph node ls osd|jq -r '.|keys|join(" ")')" --port=8080

   echo "Sleeping for 30 seconds to let rgw get going before checking health"
   sleep 30
   wait_for_health_ok

  . /etc/ansible/boto3_ansible/bin/activate
  sed -i "s/LASTNODE/001/g" /etc/ansible/hosts
  ansible-playbook /etc/ansible/ceph-rgw-users/pre-install-certs.yml
  deactivate

  ceph orch apply rgw site1 zone1 --placement="1 $(ceph node ls osd|jq -r '.|keys|join(" ")')" --port=8080

  echo "Waiting for Kubernetes config to be available..."
  while [ ! -f $KUBECONFIG ]; do
    sleep 5
  done
  shasum $KUBECONFIG | awk '{print $1}' > ${KUBECONFIG}.sum

  . /srv/cray/scripts/common/wait-for-k8s-worker.sh

  wait_for_k8s_worker

  # Send ceph.conf out to the worker nodes and disable
  # StrictHostKeyChecking for workers because ceph-deploy
  # can't handle it
  cat <<EOF >> ~/.ssh/config
Host ncn-w*
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  python3 /srv/cray/scripts/google/push-ceph-config.py

  echo "Setting a job to detect a new k8s cluster so that we can re-apply resources when necessary"
  echo "*/2 * * * * root . /etc/profile.d/cray.sh; /srv/cray/scripts/google/detect-new-k8s-cluster.sh >> /var/log/cray/cron.log 2>&1" > /etc/cron.d/cray-k8s-detect-new-cluster
  systemctl restart cron
  popd
}

function get_ceph_config() {
  echo "In vshasta google skipping ceph tunables"
}

function set_ceph_config() {
  echo "In vshasta google skipping ceph tunables"
}

function expand-root-disk() {
  echo "In expand-root-disk()"
  printf "Fix\n" | parted ---pretend-input-tty /dev/sda print
  printf "Yes\n100%%\n" | parted ---pretend-input-tty /dev/sda resizepart 2
  resize2fs /dev/sda2
}
