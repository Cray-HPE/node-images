#!/bin/bash

set -e

# Adding sysctl vars for metal.
cp -vp /srv/cray/sysctl/metal/* /etc/sysctl.d/

# Copy custom systemd files into place
cp -pv /srv/cray/resources/metal/systemd/* /usr/lib/systemd/system/
systemctl enable kdump-cray
systemctl enable cloud-init-oneshot

# Adding sshd_config for metal.
cp -vp /srv/cray/resources/metal/sshd_config /etc/ssh/sshd_config

# Setup dracut to pull new fstab changes in from fstab.metal if it exists.
function dracut {
    local metal_conf=/etc/dracut.conf.d/05-metal.conf
    local metal_fstab=/etc/fstab.metal

    [ ! -f $metal_conf ] && touch $metal_conf

    if grep -q "$metal_fstab" "$metal_conf" ; then :
    else
        printf 'add_fstab+=%s\n' "$metal_fstab" >$metal_conf
    fi
}
dracut
