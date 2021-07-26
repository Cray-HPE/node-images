#!/usr/bin/env bash

function reconfigure-apparmor {
  echo "Reconfiguring apparmor for haproxy"
  sed -i -e '/inet6/a\' -e '  /etc/ceph/rgw.pem r,' /etc/apparmor.d/usr.sbin.haproxy
  systemctl restart apparmor.service
}
