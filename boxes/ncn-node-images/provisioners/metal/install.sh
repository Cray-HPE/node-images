#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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

# Adding tmpfiles for metal.
cp -pvr /srv/cray/resources/metal/tmpfiles.d/* /usr/lib/tmpfiles.d/

echo "Loading in sysctl settings; activating for build-time"
# Adding sysctl vars for metal.
cp -pvr /srv/cray/sysctl/metal/* /etc/sysctl.d/
sysctl -p

# Adding cloud-init.cfg files and templates for metal.
# Do not delete anything there, incase a lower layer already added common configs.
[ -f /etc/cloud/cloud.cfg ] || cp -pv /srv/cray/resources/common/cloud.cfg /etc/cloud/
rsync -av /srv/cray/resources/metal/cloud.cfg.d/ /etc/cloud/cloud.cfg.d/

# enable this to run on first boot during deployment, and then the kdump script disables it
systemctl enable kdump-cray
