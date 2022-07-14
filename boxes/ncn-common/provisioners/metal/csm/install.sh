#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
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
    rsync -av /srv/cray/resources/common/cloud/templates/ ${base}/templates/ || echo 'No templates to copy.'

    # Enable cloud-init at boot
    systemctl enable cloud-config
    systemctl enable cloud-init
    systemctl enable cloud-init-local
    systemctl enable cloud-final
}
cloud

function motd {
    # Add motd/flair
    cp -pv /srv/cray/resources/common/motd /etc/motd
}
motd
