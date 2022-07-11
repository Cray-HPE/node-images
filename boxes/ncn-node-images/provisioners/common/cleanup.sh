#!/usr/bin/env bash

set -ex

echo "removing our autoyast cache to ensure no lingering sensitive content remains there from install"
rm -rf /var/adm/autoinstall/cache

echo "cleanup all the downloaded RPMs"
zypper clean --all

echo "clean up network interface persistence"
rm -f /etc/udev/rules.d/70-persistent-net.rules;
touch /etc/udev/rules.d/75-persistent-net-generator.rules;

echo "truncate any logs that have built up during the install"
find /var/log/ -type f -name "*.log.*" -exec rm -rf {} \;
find /var/log -type f -exec truncate --size=0 {} \;

echo "remove the contents of /tmp and /var/tmp"
rm -rf /tmp/* /var/tmp/*

echo "blank netplan machine-id (DUID) so machines get unique ID generated on boot"
truncate -s 0 /etc/machine-id

echo "force a new random seed to be generated"
rm -f /var/lib/systemd/random-seed

echo "clear the history so our install isn't there"
rm -f /root/.wget-hsts
export HISTSIZE=0

# Handle ext2/3/4 or xfs.
echo "Running defrag -- this can take a while ... "
if ! e4defrag /; then
    if ! xfs_fsr /; then
        echo >&2 "Neither e4defrag nor xfs_fsr could defragment the root device. Potential filesystem mismatch on [/]."
        mount | grep ' / '
    fi
fi
echo 'Defrag completed'

echo "Write zeros..."
filler="$(($(df -BM --output=avail /|grep -v Avail|cut -d "M" -f1)-1024))"
dd if=/dev/zero of=/root/zero-file bs=1M count=$filler
rm /root/zero-file
