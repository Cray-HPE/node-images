#!/bin/bash

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

set -e

echo "Ensuring /srv/cray/utilities locations are available for use system-wide"
ln -s /srv/cray/utilities/common/craysys/craysys /bin/craysys
echo "export PYTHONPATH=\"/srv/cray/utilities/common\"" >> /etc/profile.d/cray.sh

echo "Configuring podman so it will run with fuse-overlayfs"
sed -i 's/.*mount_program =.*/mount_program = "\/usr\/bin\/fuse-overlayfs"/' /etc/containers/storage.conf

echo "Enabling services"
systemctl enable multi-user.target
systemctl set-default multi-user.target
systemctl enable ca-certificates.service
systemctl enable issue-generator.service
systemctl enable kdump-early.service
systemctl enable kdump.service
systemctl enable purge-kernels.service
systemctl enable rasdaemon.service
systemctl enable rc-local.service
systemctl enable rollback.service
systemctl enable sshd.service
systemctl enable wicked.service
systemctl enable wickedd-auto4.service
systemctl enable wickedd-dhcp4.service
systemctl enable wickedd-dhcp6.service
systemctl enable wickedd-nanny.service
systemctl enable getty@tty1.service
systemctl enable serial-getty@ttyS0.service
systemctl enable --now lldpad.service
systemctl disable postfix.service && systemctl stop postfix.service
systemctl enable chronyd.service
systemctl enable spire-agent.service
systemctl enable --now goss-servers

pip3 install --upgrade pip
pip3 install requests
