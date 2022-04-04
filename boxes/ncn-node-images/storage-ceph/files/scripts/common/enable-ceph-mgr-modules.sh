function enable_ceph_prometheus() {
  echo "Enabling ceph mgr prometheus module"
  ceph mgr module enable prometheus
}
