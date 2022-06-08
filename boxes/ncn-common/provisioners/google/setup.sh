#!/bin/bash

set -e

echo "activate public cloud module"
product=$(SUSEConnect --list-extensions | grep -o "sle-module-public-cloud.*")
[[ -n "$product" ]] && SUSEConnect -p "$product"

# NOTE: This is only used during the build process and is removed at the end
echo "Modifying DNS to use Cray DNS servers..."
cp /etc/sysconfig/network/config /etc/sysconfig/network/config.backup
sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*$|NETCONFIG_DNS_STATIC_SERVERS="172.31.84.40 172.30.84.40"|g' /etc/sysconfig/network/config
systemctl restart network
