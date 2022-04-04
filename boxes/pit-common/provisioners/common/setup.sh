#!/bin/bash

set -e

GOSS_BASE=/opt/cray/tests/install/livecd

echo "Initializing log location(s)"
mkdir -p /var/log/cray
cat << 'EOF' > /etc/logrotate.d/cray
/var/log/cray/*.log {
  size 1M
  create 744 root root
  rotate 4
}
EOF

echo "Initializing directories and resources"
mkdir -p /srv/cray
cp -r /tmp/files/* /srv/cray/
chmod +x -R /srv/cray/scripts
rm -rf /tmp/files

# Change hostname from lower layer to ncn.
echo 'pit' > /etc/hostname
