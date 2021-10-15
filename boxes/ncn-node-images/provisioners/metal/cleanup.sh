#!/usr/bin/env bash

set -ex

SLES_VERSION=$(grep -i VERSION= /etc/os-release | tr -d '"' | cut -d '-' -f2)
echo "purging $SLES_VERSION services repos"
for repo in $(zypper ls | awk '{print $3}' | grep -E $SLES_VERSION); do
    zypper rs $repo
done

echo "remove credential files"
rm -f /root/.zypp/credentials.cat
rm -f /etc/zypp/credentials.cat
rm -f /etc/zypp/credentials.d/*