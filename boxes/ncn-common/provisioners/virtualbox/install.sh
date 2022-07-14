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

# install required packages for virtualbox
packages=( bzip2 gcc jq make kernel-devel kernel-macros kernel-default-devel )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"

# Installing the virtualbox guest additions
# Allow unsupported modules
sed -i -e 's#^allow_unsupported_modules 0#allow_unsupported_modules 1#' /etc/modprobe.d/10-unsupported-modules.conf
# Do the install
VBOX_VERSION=$(cat /root/.vbox_version)
cd /tmp
mount -o loop /root/VBoxGuestAdditions_$VBOX_VERSION.iso /mnt || echo "unable to mount virtual box guest additions iso"
sh /mnt/VBoxLinuxAdditions.run install --force || echo "unable to install driver"
umount /mnt || echo "unable to umount iso"
rm -rf /root/VBoxGuestAdditions_*.iso || echo "unable to rm iso"
echo "guest additions installed"
