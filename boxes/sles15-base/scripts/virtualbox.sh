#!/usr/bin/env bash

set -e

# Installing the virtualbox guest additions
# Allow unsupported modules
sed -i -e 's#^allow_unsupported_modules 0#allow_unsupported_modules 1#' /etc/modprobe.d/10-unsupported-modules.conf
# Do the install
VBOX_VERSION=$(cat /root/.vbox_version)
cd /tmp
mount -o loop /root/VBoxGuestAdditions_$VBOX_VERSION.iso /mnt || echo "unable to mount virtual box guest additions iso"
sh /mnt/VBoxLinuxAdditions.run install --force || echo "unable to install driver"
umount /mnt || echo "unable to umount iso"
rm -rf /root/VBoxGuestAdditions_*.iso || echo "unable to rm iso"
echo "guest additions installed"