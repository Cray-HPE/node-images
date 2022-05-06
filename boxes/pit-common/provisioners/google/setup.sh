#!/bin/bash

set -e

# Establish that this is a google system
touch /etc/google_system

echo "activate public cloud module"
product=$(SUSEConnect --list-extensions | grep -o "sle-module-public-cloud.*")
[[ -n "$product" ]] && SUSEConnect -p "$product"

echo "install guest environment packages"
zypper refresh
zypper install -y google-guest-{agent,configs,oslogin} google-osconfig-agent
systemctl enable /usr/lib/systemd/system/google-*

echo "Modifying DNS to use Cray DNS servers..."
cp /etc/sysconfig/network/config /etc/sysconfig/network/config.backup
sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*$|NETCONFIG_DNS_STATIC_SERVERS="172.31.84.40 172.30.84.40"|g' /etc/sysconfig/network/config
systemctl restart network

echo "Stubbing out network interface configuration files"
for i in {0..10}; do
  cat << 'EOF' > /etc/sysconfig/network/ifcfg-eth${i}
BOOTPROTO='dhcp'
STARTMODE='auto'
EOF
done

# TODO: something keeps removing authorized_keys for root, at the very least in Virtual Shasta, we need it to stick around
echo "Scheduling job to ensure /root/.ssh/authorized_keys file is our /root/.ssh/id_rsa.pub only every 1 minute"
echo "*/1 * * * * cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys >> /var/log/cray/cron.log 2>&1" > /etc/cron.d/cray-maintain-root-authorized-keys
