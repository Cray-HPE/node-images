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

set -ex

# Ensure that only the desired kernel version may be installed.
# Clean up old kernels, if any. We should only ship with a single kernel.
# Lock the kernel to prevent inadvertent updates.
function kernel {
    local sles15_kernel_version
    sles15_kernel_version=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}\n" kernel-default)

    echo "Purging old kernels ... "
    sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf
    zypper --non-interactive purge-kernels --details

    echo "Locking the kernel to $SLES15_KERNEL_VERSION"
    zypper addlock kernel-default

    echo 'Listing locks and kernel RPM(s)'
    zypper ll
    rpm -qa | grep kernel-default   
}
kernel

# Disable undesirable kernel modules
function kernel_modules {
    local disabled_modules="libiscsi"
    local modprobe_file=/etc/modprobe.d/disabled-modules.conf

    touch $modprobe_file

    for mod in $disabled_modules; do
        echo "install $mod /bin/true" >> $modprobe_file
    done
}
kernel_modules

echo 'Adding python->python3 symlink'
ln -snf /usr/bin/python3 /usr/bin/python

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


# Make virtualenv available to all contexts and teams.
pip3 install virtualenv

kubernetes_version="1.20.13-0"
echo "Ensuring that the kubernetes package repo exists in zypper"
if ! zypper repos | grep google-kubernetes; then
  zypper addrepo --gpgcheck-strict --refresh https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 google-kubernetes
fi
echo "Ensuring that we have the necessary gpg keys from google-kubernetes repo"
rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg
curl -o /tmp/apt-key.gpg.asc https://packages.cloud.google.com/yum/doc/apt-key.gpg.asc
echo "" >> /tmp/apt-key.gpg.asc
rpm --import /tmp/apt-key.gpg.asc
zypper refresh google-kubernetes
zypper install -y kubectl-${kubernetes_version}
zypper -n removerepo google-kubernetes || true

pip3 install --upgrade pip
pip3 install requests
