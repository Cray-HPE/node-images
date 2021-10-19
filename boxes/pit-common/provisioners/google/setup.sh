#!/bin/bash

set -e

echo "Stubbing out network interface configuration files"
for i in {0..10}; do
  cat << 'EOF' > /etc/sysconfig/network/ifcfg-eth${i}
BOOTPROTO='dhcp'
STARTMODE='auto'
EOF
done
cp /srv/cray/sysctl/google/* /etc/sysctl.d/

# TODO: something keeps removing authorized_keys for root, at the very least in Virtual Shasta, we need it to stick around
echo "Scheduling job to ensure /root/.ssh/authorized_keys file is our /root/.ssh/id_rsa.pub only every 1 minute"
echo "*/1 * * * * cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys >> /var/log/cray/cron.log 2>&1" > /etc/cron.d/cray-maintain-root-authorized-keys
