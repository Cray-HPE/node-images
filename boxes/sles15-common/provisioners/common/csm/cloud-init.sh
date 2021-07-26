#!/usr/bin/env bash
#
# Cray System Management
#
set -e

function cloud {
    echo 'Setting cloud-init config'
    local base=/etc/cloud/
    cp -pv /srv/cray/resources/common/cloud.cfg /etc/cloud/
    rsync -av --delete /srv/cray/resources/common/cloud.cfg.d/ /etc/cloud/cloud.cfg.d/
    # remove default ntp module and replace it with our custom one
    rm -f /usr/lib/python3.6/site-packages/cloudinit/config/cc_ntp.py
    cp /srv/cray/resources/common/cloud/cc_ntp.py /usr/lib/python3.6/site-packages/cloudinit/config/cc_ntp.py
    # do the same for the timezone module (where it's modified to change the hwclock as well)
    rm -f /usr/lib/python3.6/site-packages/cloudinit/config/cc_timezone.py
    cp /srv/cray/resources/common/cloud/cc_timezone.py /usr/lib/python3.6/site-packages/cloudinit/config/cc_timezone.py
    systemctl enable cloud-config
    systemctl enable cloud-init
    systemctl enable cloud-init-local
    systemctl enable cloud-final
}
cloud
