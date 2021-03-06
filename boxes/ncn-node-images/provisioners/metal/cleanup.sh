#!/usr/bin/env bash

set -ex

SLES_VERSION=$(grep -i VERSION= /etc/os-release | tr -d '"' | cut -d '-' -f2)
echo "purging $SLES_VERSION services repos"
for repo in $(zypper ls | awk '{print $3}' | grep -E $SLES_VERSION); do
    zypper rs $repo
done


echo "remove /etc/shadow entry for root"
seconds_per_day=$(( 60*60*24 ))
days_since_1970=$(( $(date +%s) / seconds_per_day ))
sed -i "/^root:/c\root:\*:$days_since_1970::::::" /etc/shadow

echo "remove root's .ssh directory"
rm -rvf /root/.ssh

echo "remove ssh host keys"
rm -fv /etc/ssh/ssh_host*

echo "remove credential files"
rm -vf /root/.zypp/credentials.cat
rm -vf /etc/zypp/credentials.cat
rm -vf /etc/zypp/credentials.d/*
