#!/usr/bin/env bash

set -e

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

echo "remove credential files"
rm -f /root/.zypp/credentials.cat
rm -f /etc/zypp/credentials.cat
rm -f /etc/zypp/credentials.d/*

echo "clear the history so our install isn't there"
rm -f /root/.wget-hsts
export HISTSIZE=0