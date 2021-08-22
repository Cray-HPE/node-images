#!/bin/bash

num_storage_nodes=$(craysys metadata get num_storage_nodes)
export RGW_VIRTUAL_IP=$(craysys metadata get rgw-virtual-ip)
wipe=$(craysys metadata get wipe-ceph-osds)

function init() {

  for node in $(seq 1 $num_storage_nodes); do
    nodename=$(printf "ncn-s%03d" $node)
    echo "Checking for node $nodename status"
    until nc -z -w 10 $nodename 22; do
      echo "Waiting for $nodename to be online, sleeping 60 seconds between polls"
      sleep 60
    done
  done

  for node in $(seq 1 $num_storage_nodes); do
   nodename=$(printf "ncn-s%03d" $node)
   ssh-keyscan -H $nodename >> ~/.ssh/known_hosts
  done

  if [ $wipe == 'yes' ]; then
    ansible osds -m shell -a "vgremove -f --select 'vg_name=~ceph*'"
  fi

  . /srv/cray/scripts/common/fix_ansible_inv.sh
  fix_inventory  

  cd /etc/ansible/ceph-ansible
  ansible-playbook /etc/ansible/ceph-rgw-users/pre-install-certs.yml
  ansible-playbook /etc/ansible/ceph-rgw-users/ceph-haproxy-setup.yml
  ansible-playbook site.yml
  ansible-playbook /etc/ansible/ceph-rgw-users/radosgw-sts-setup.yml
  . /srv/cray/scripts/common/enable-ceph-mgr-modules.sh
  enable_ceph_prometheus
  . /srv/cray/scripts/common/wait-for-k8s-worker.sh
  wait_for_k8s_worker
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
  for osd in $(ceph osd ls)
   do
    ceph config set osd.$osd bluestore_cache_autotune false
    ceph config set osd.$osd bluestore_rocksdb_options compression=kNoCompression,max_write_buffer_number=32,min_write_buffer_number_to_merge=2,recycle_log_file_num=32,compaction_style=kCompactionStyleLevel,write_buffer_size=67108864,target_file_size_base=67108864,max_background_compactions=31,level0_file_num_compaction_trigger=8,level0_slowdown_writes_trigger=32,level0_stop_writes_trigger=64,max_bytes_for_level_base=536870912,compaction_threads=32,max_bytes_for_level_multiplier=8,flusher_threads=8,compaction_readahead_size=2MB
    ceph config set osd.$osd bluestore_cache_kv_ratio 0.2
    ceph config set osd.$osd bluestore_cache_meta_ratio 0.8
    ceph config set osd.$osd osd_min_pg_log_entries 100
    ceph config set osd.$osd osd_max_pg_log_entries 100
    ceph config set osd.$osd osd_pg_log_dups_tracked 100
    ceph config set osd.$osd osd_pg_log_trim_min 100
    ceph config set osd.$osd osd_max_backfills 10
    ceph config set osd.$osd osd_recovery_max_active 4
   done

  echo "setting rgw max user shards"
  ceph config set client.radosgw  rgw_usage_max_user_shards 16
 
  echo "restarting ceph osd services"
  ansible osds -m shell -a "systemctl restart ceph-osd.target"
}
