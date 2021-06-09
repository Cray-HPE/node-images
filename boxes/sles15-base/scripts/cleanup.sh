#!/usr/bin/env bash

set -e

# Zero out the free space to save space in the final image:
rm -rf /var/adm/autoinstall/cache
rm -rf /home/vagrant/*.sh
rm -rf /home/vagrant/.v*
# Because cloning a VM will make a new network interface
truncate -s 0 /etc/udev/rules.d/70-persistent-net.rules
#dd if=/dev/zero of=/EMPTY bs=1M
#rm -f /EMPTY