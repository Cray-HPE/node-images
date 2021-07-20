#!/usr/bin/env bash

set -e

echo "Removing our autoyast cache to ensure no lingering sensitive content remains there from install"
rm -rf /var/adm/autoinstall/cache

# Because cloning a VM will make a new network interface
truncate -s 0 /etc/udev/rules.d/70-persistent-net.rules