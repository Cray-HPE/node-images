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
set -e

echo "Moving ceph metal operations files into place"
mv /srv/cray/resources/metal/ansible/* /etc/ansible/

# Adding sysctl vars for metal.
echo "Configuring sysctl to allow non-local vip binding"
cp /srv/cray/sysctl/metal/* /etc/sysctl.d/
sysctl -p

# enable this to run on first boot during deployment, and then the kdump script disables it
systemctl enable kdump-cray

echo 'Setting cloud-init config'
# allow override; if no cloud.cfg file, copy one in from this image; help local-builds.
[ -f /etc/cloud/cloud.cfg ] || cp -pv /srv/cray/resources/common/cloud.cfg /etc/cloud/
rsync -av /srv/cray/resources/metal/cloud.cfg.d/ /etc/cloud/cloud.cfg.d/
