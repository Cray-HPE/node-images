#!/bin/bash

num_storage_nodes=$(craysys metadata get num_storage_nodes)
export RGW_VIRTUAL_IP=$(craysys metadata get rgw-virtual-ip)
wipe=$(craysys metadata get wipe-ceph-osds)

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
  num_storage_nodes=$(craysys metadata get num-storage-nodes)
  for node in $(seq 1 $num_storage_nodes); do
    nodename=$(printf "ncn-s%03d" $node)
    echo "Calling cephadm prepare-host for $nodename..."
    ceph cephadm prepare-host $nodename
  done
}

function wait_for_osds() {
  num_storage_nodes=$(craysys metadata get num-storage-nodes)
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

  export num_storage_nodes=$(craysys metadata get num-storage-nodes)
  echo "number of storage nodes: $num_storage_nodes"

  for node in $(seq 1 $num_storage_nodes); do
    nodename=$(printf "ncn-s%03d.nmn" $node)
    echo "Checking for node $nodename status"
    until nc -z -w 10 $nodename 22; do
      echo "Waiting for $nodename to be online, sleeping 60 seconds between polls"
      sleep 60
    done
  done

  for node in $(seq 1 $num_storage_nodes); do
   nodename=$(printf "ncn-s%03d.nmn" $node)
   ssh-keyscan -t rsa -H $nodename >> ~/.ssh/known_hosts
  done

  if [[ "$(hostname)" =~ "ncn-s001" ]]; then
    cephadm --retry 60 --image $registry/ceph/ceph:v$CEPH_VERS bootstrap --skip-monitoring-stack --skip-dashboard --skip-pull --mon-ip $(ip -4 -br  address show dev vlan002 |awk '{split($3,ip,"/"); print ip[1]}')
    cephadm shell -- ceph -s

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

   ceph cephadm generate-key
   ceph cephadm get-pub-key > /etc/ceph/ceph.pub
   for node in $(seq 1 $num_storage_nodes); do
     nodename=$(printf "ncn-s%03d" $node)
     ssh-keyscan -t rsa -H $nodename >> ~/.ssh/known_hosts
   done

# Get the ceph osd configs, set our tunable params, then dump the config so we have a record that the changes occured

  if [ -f "$ceph_tuning_file" ]; then
    echo "This ceph cluster has already been tuned"
  else
    echo "Tuning ceph"
    set_ceph_config
    enable_sts
    mark_initialized $ceph_tuning_file
  fi

   until [[ "$hosts_added" -ge "$num_storage_nodes" ]]
   do
     for node in $(seq 1 $num_storage_nodes)
     do
       nodename=$(printf "ncn-s%03d" $node)
       ssh-copy-id -f -i /etc/ceph/ceph.pub root@$nodename
     done

     for node in $(seq 1 $num_storage_nodes)
     do
       nodename=$(printf "ncn-s%03d" $node)
       ceph orch host add $nodename
     done

     hosts_added=0
     for node in $(seq 1 $num_storage_nodes)
      do
       nodename=$(printf "ncn-s%03d" $node)
       node_status=$(ceph cephadm check-host $nodename|awk '{print $3}')
       if [[ $node_status == "ok" ]]
       then
        hosts_added=$((hosts_added+1))
       fi
      done
   done

   echo "Container image values"
   ceph config set mgr mgr/cephadm/container_image_grafana       "$registry/ceph/ceph-grafana:6.7.4"
   ceph config set mgr mgr/cephadm/container_image_prometheus    "$registry/prometheus/prometheus:v2.18.1"
   ceph config set mgr mgr/cephadm/container_image_alertmanager  "$registry/quay.io/prometheus/alertmanager:v0.21.0"
   ceph config set mgr mgr/cephadm/container_image_node_exporter "$registry/quay.io/prometheus/node-exporter:v1.2.2"

   echo "Dashboard and monitoring images values set"

   echo "Deploying alertmanager, grafana, node-exporter and prometheus"
   ceph orch apply alertmanager
   ceph orch apply grafana
   ceph orch apply node-exporter
   ceph orch apply prometheus

   for SERVICE in mon mgr osd mds client
    do
     CURRENT_IMG_VALUE=$(ceph config get $SERVICE container_image)
     echo "Current image value for $SERVICE is $CURRENT_IMG_VALUE"
     if [[ "$CURRENT_IMG_VALUE" != "$registry/ceph/ceph:v$CEPH_VERS" ]]
     then
      ceph config set $SERVICE container_image $registry/ceph/ceph:v$CEPH_VERS
     fi
    done

   echo "Sleeping for 30 seconds to allow ceph devices to discover"
   sleep 30

   if [ "$wipe" == "yes" ]; then
     for node in $(ceph orch device ls -f json-pretty|jq -r '.[].name');
     do
       for disk in $(ceph orch device ls $node -f json-pretty | jq -r '.[].devices[] | select(.available==false)|.path');
       do
         echo "Zapping disk $disk for node $node"
         ceph orch device zap  $node $disk --force
       done
     done
   fi

   echo "Calling prepare hosts"
   prepare_hosts

   check_for_duplicate_mgr

   echo "Running ceph orch apply mon"
   ceph orch apply mon --placement="3 ncn-s001 ncn-s002 ncn-s003"

   echo "Running ceph orch apply mgr"
   ceph orch apply mgr --placement="3 ncn-s001 ncn-s002 ncn-s003"

   echo "Calling prepare hosts"
   prepare_hosts

   echo "Running ceph orch apply osd"
   ceph orch apply osd --all-available-devices

   echo "Sleeping for 30 seconds to let osds settle"
   sleep 30

   wait_for_osds
   wait_for_health_ok

   echo "Creating placement group for cephfs"
   ceph fs volume create cephfs --placement="3 ncn-s001 ncn-s002 ncn-s003"

   echo "Sleeping for 30 seconds to let cephfs get going before checking health"
   sleep 30
   wait_for_health_ok

   echo "Setting cephfs allow_standby_replay true"
   ceph fs set cephfs allow_standby_replay true

   ceph orch apply rgw site1 zone1 --placement="${num_storage_nodes} $(ceph node ls osd|jq -r '.|keys|join(" ")')" --port=8080

   echo "Sleeping for 30 seconds to let rgw get going before checking health"
   sleep 30
   wait_for_health_ok

  fi
  . /etc/ansible/boto3_ansible/bin/activate
  . /srv/cray/scripts/common/fix_ansible_inv.sh
  fix_inventory
  cd /etc/ansible/ceph-ansible
  ansible-playbook /etc/ansible/ceph-rgw-users/pre-install-certs.yml
  deactivate

  ceph config generate-minimal-conf > /etc/ceph/ceph_conf_min
  cp /etc/ceph/ceph_conf_min /etc/ceph/ceph.conf

  for host in $(ceph node ls| jq -r '.osd|keys[]'); do
    scp /etc/ceph/* $host:/etc/ceph
  done

  for host in $(ceph node ls| jq -r '.osd|keys[]'); do
    ssh $host '. /srv/cray/scripts/metal/update_apparmor.sh; reconfigure-apparmor'
    ssh $host '/srv/cray/scripts/metal/generate_keepalived_conf.sh > /etc/keepalived/keepalived.conf; systemctl enable keepalived.service; systemctl restart keepalived.service'
    ssh $host '/srv/cray/scripts/metal/generate_haproxy_cfg.sh > /etc/haproxy/haproxy.cfg; systemctl enable haproxy.service; systemctl restart haproxy.service'
  done

}

function get_ceph_config() {
  echo "getting ceph tunable parameters"
  for osd in $(ceph osd ls)
   do
    echo "fetching values for "osd.$osd
    echo "bluestore_cache_autotune = "$(ceph config get osd.$osd bluestore_cache_autotune);
    echo "bluestore_rocksdb_options = "$(ceph config get osd.$osd bluestore_rocksdb_options);
    echo "bluestore_cache_kv_ratio = "$(ceph config get osd.$osd bluestore_cache_kv_ratio);
    echo "bluestore_cache_meta_ratio = "$(ceph config get osd.$osd bluestore_cache_meta_ratio);
    echo "osd_min_pg_log_entries = "$(ceph config get osd.$osd osd_min_pg_log_entries);
    echo "osd_max_pg_log_entries = "$(ceph config get osd.$osd osd_max_pg_log_entries);
    echo "osd_pg_log_dups_tracked = "$(ceph config get osd.$osd osd_pg_log_dups_tracked);
    echo "osd_pg_log_trim_min = "$(ceph config get osd.$osd osd_pg_log_trim_min);
    echo "osd_max_backfills = "$(ceph config get osd.$osd osd_max_backfills);
    echo "osd_recovery_max_active = "$(ceph config get osd.$osd osd_recovery_max_active);
  done
}

function set_ceph_config() {
  echo "setting ceph tunable parameters"
  ceph config set osd bluestore_cache_autotune false
  ceph config set osd bluestore_rocksdb_options compression=kNoCompression,max_write_buffer_number=32,min_write_buffer_number_to_merge=2,recycle_log_file_num=32,compaction_style=kCompactionStyleLevel,write_buffer_size=67108864,target_file_size_base=67108864,max_background_compactions=31,level0_file_num_compaction_trigger=8,level0_slowdown_writes_trigger=32,level0_stop_writes_trigger=64,max_bytes_for_level_base=536870912,compaction_threads=32,max_bytes_for_level_multiplier=8,flusher_threads=8,compaction_readahead_size=2MB
  ceph config set osd bluestore_cache_kv_ratio 0.2
  ceph config set osd bluestore_cache_meta_ratio 0.8
  ceph config set osd osd_min_pg_log_entries 100
  ceph config set osd osd_max_pg_log_entries 100
  ceph config set osd osd_pg_log_dups_tracked 100
  ceph config set osd osd_pg_log_trim_min 100
  ceph config set osd osd_max_backfills 10
  ceph config set osd osd_recovery_max_active 4

  echo "setting rgw max user shards"
  ceph config set client.radosgw  rgw_usage_max_user_shards 16
}

function expand-root-disk() {
  echo "In expand-root-disk() -- skipping since we're on metal"
}

