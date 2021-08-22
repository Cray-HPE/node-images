#!/usr/bin/env bash

set -e

echo "Moving ceph metal operations files into place"
mv /srv/cray/resources/metal/ansible/* /etc/ansible/

# Adding sysctl vars for metal.
echo "Configuring sysctl to allow non-local vip binding"
cp /srv/cray/sysctl/metal/* /etc/sysctl.d/
zypper -n install -y golang-github-prometheus-node_exporter
sysctl -p

# enable this to run on first boot during deployment, and then the kdump script disables it
systemctl enable kdump-cray

echo 'Setting cloud-init config'
# allow override; if no cloud.cfg file, copy one in from this image; help local-builds.
[ -f /etc/cloud/cloud.cfg ] || cp -pv /srv/cray/resources/metal/cloud.cfg /etc/cloud/
rsync -av --delete /srv/cray/resources/metal/cloud.cfg.d/ /etc/cloud/cloud.cfg.d/

systemctl enable cloud-config
systemctl enable cloud-init
systemctl enable cloud-init-local
systemctl enable cloud-final