#!/bin/bash
#
# Cray System Management : METAL
# To be installed on all mediums (Google, Metal, etc.)
set -e

function cloud {
    echo 'Setting cloud-init config'
    local base=/etc/cloud

    # Copy the base config.
    # Clean out any pre-existing configs; nothing should exist in the ncn-common layer here.
    mkdir -pv $base || echo "$base already exists"
    cp -pv /srv/cray/resources/common/cloud.cfg ${base}/
    rsync -av --delete /srv/cray/resources/common/cloud.cfg.d/ ${base}/cloud.cfg.d/ || echo 'No cloud-init configs to copy.'
    rsync -av /srv/cray/resources/common/cloud/src/ /usr/lib/python3.6/site-packages/cloudinit/config/ || echo 'No cloud-init configs to copy.'
    rsync -av /srv/cray/resources/common/cloud/templates/ ${base}/templates/ || echo 'No templates to copy.'

    # Enable cloud-init at boot
    systemctl enable cloud-config
    systemctl enable cloud-init
    systemctl enable cloud-init-local
    systemctl enable cloud-final
}
cloud
