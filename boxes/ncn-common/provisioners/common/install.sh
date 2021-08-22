#!/usr/bin/env bash

set -e

echo "Ensuring /srv/cray/utilities locations are available for use system-wide"
ln -s /srv/cray/utilities/common/craysys/craysys /bin/craysys
echo "export PYTHONPATH=\"/srv/cray/utilities/common\"" >> /etc/profile.d/cray.sh


DISABLED_MODULES="libiscsi"
MODPROBE_FILE=/etc/modprobe.d/disabled-modules.conf
echo "Removing modules: $DISABLED_MODULES"
touch $MODPROBE_FILE
for mod in $DISABLED_MODULES; do
    echo "install $mod /bin/true" >> $MODPROBE_FILE
done


echo "Setting /usr/bin/python -> /usr/bin/python3 symlink"
ln -snf /usr/bin/python3 /usr/bin/python

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
systemctl enable lldpad.service
systemctl disable postfix.service && systemctl stop postfix.service
systemctl enable chronyd.service
systemctl enable spire-agent.service

pip3 install --upgrade pip
pip3 install requests
