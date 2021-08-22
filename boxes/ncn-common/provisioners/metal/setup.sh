#!/usr/bin/env bash

set -e

# Adding sysctl vars for metal.
cp -vp /srv/cray/sysctl/metal/* /etc/sysctl.d/

# Copy custom systemd files into place
cp -pv /srv/cray/resources/metal/systemd/* /usr/lib/systemd/system/
systemctl enable kdump-cray
systemctl enable cloud-init-oneshot

# Adding sshd_config for metal.
cp -vp /srv/cray/resources/metal/sshd_config /etc/ssh/sshd_config
