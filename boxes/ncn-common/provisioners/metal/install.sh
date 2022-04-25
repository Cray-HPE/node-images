#!/bin/bash

set -ex

# HPC metal clusters reflect their nature through the SLES HPC Release RPM.
# The conflicting RPM needs to be removed
# Forcing the the HPC rpm because removing sles-release auto removes dependencies
# even with -U when installing with inventory file
echo "Etching release file"
zypper removelock kernel-default || echo 'No lock to remove'
zypper -n install --auto-agree-with-licenses --force-resolution SLE_HPC-release
zypper addlock kernel-default

echo "Enabling sysstat service for metal only"
cp -pv /srv/cray/resources/metal/sysstat.cron /etc/sysstat/sysstat.cron
/usr/lib64/sa/sa1 -S DISK 1 1
systemctl enable sysstat.service

echo "Adding mdadm.conf"
cp -pv /srv/cray/resources/metal/mdadm.conf /etc/

# Agentless Management Service only works on servers with iLO4/5.
# Disable by default, enable during runtime.
function ams {
    echo "Disabling Agentless Management Daemon"
    systemctl disable ahslog
    systemctl disable amsd
    systemctl disable cpqFca
    systemctl disable cpqIde
    systemctl disable cpqScsi
    systemctl disable smad
    systemctl stop ahslog
    systemctl stop amsd
    systemctl stop cpqFca
    systemctl stop cpqIde
    systemctl stop cpqScsi
    systemctl stop smad
}
ams

# Allow domains.
sed -i 's/^DHCLIENT_FQDN_ENABLED=.*/DHCLIENT_FQDN_ENABLED="enabled"/' /etc/sysconfig/network/dhcp
# Notify update on hostname change.
sed -i 's/^DHCLIENT_FQDN_UPDATE=.*/DHCLIENT_FQDN_UPDATE="both"/' /etc/sysconfig/network/dhcp
# Do not let DHCP set hostname, this is set by cloud-init.
sed -i 's/^DHCLIENT_SET_HOSTNAME=.*/DHCLIENT_SET_HOSTNAME="no"/' /etc/sysconfig/network/dhcp
