#!/bin/bash

set -ex

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

zypper addrepo https://download.opensuse.org/repositories/openSUSE:Backports:SLE-15-SP3/standard/openSUSE:Backports:SLE-15-SP3.repo
zypper --gpg-auto-import-keys refresh
zypper install -y libfmt7

zypper addrepo https://download.opensuse.org/repositories/filesystems:ceph/openSUSE_Leap_15.3/filesystems:ceph.repo
zypper --gpg-auto-import-keys refresh
zypper install -y --recommends --force-resolution ceph-common=16.2.7.654+gd5a90ff46f0-lp153.3852.1
#zypper install python3-ceph-common=16.2.7.654+gd5a90ff46f0-lp153.3852.1
zypper -n removerepo filesystems_ceph
zypper -n removerepo openSUSE_Backports_SLE-15-SP3

pip3 install --upgrade pip
pip3 install requests
