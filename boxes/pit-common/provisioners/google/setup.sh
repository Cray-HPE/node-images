#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -e

# Establish that this is a google system
touch /etc/google_system

echo "activate public cloud module"
product=$(SUSEConnect --list-extensions | grep -o "sle-module-public-cloud.*")
[[ -n "$product" ]] && SUSEConnect -p "$product"

echo "Enable guest environment services"
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
