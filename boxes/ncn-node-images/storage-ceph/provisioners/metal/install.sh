#!/bin/bash

set -e

echo "Moving ceph metal operations files into place"
mv /srv/cray/resources/metal/ansible/* /etc/ansible/

# Adding sysctl vars for metal.
echo "Configuring sysctl to allow non-local vip binding"
cp /srv/cray/sysctl/metal/* /etc/sysctl.d/
sysctl -p

echo 'Setting cloud-init config'
# allow override; if no cloud.cfg file, copy one in from this image; help local-builds.
[ -f /etc/cloud/cloud.cfg ] || cp -pv /srv/cray/resources/common/cloud.cfg /etc/cloud/
rsync -av /srv/cray/resources/metal/cloud.cfg.d/ /etc/cloud/cloud.cfg.d/
