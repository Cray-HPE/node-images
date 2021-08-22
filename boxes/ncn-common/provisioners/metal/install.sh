#!/bin/bash

set -e

echo "Enabling sysstat service for metal only"
mkdir -pv /etc/sysstat/
cp -pv /srv/cray/resources/metal/sysstat.cron /etc/sysstat/sysstat.cron
/usr/lib64/sa/sa1 -S DISK 1 1
systemctl enable sysstat.service

echo "Adding mdadm.conf"
cp -pv /srv/cray/resources/metal/mdadm.conf /etc/

# Agentless Management Service only works on servers with iLO4/5; disable by default.
if rpm -qi amsd ; then
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
fi

# Allow domains.
sed -i 's/^DHCLIENT_FQDN_ENABLED=.*/DHCLIENT_FQDN_ENABLED="enabled"/' /etc/sysconfig/network/dhcp
# Notify update on hostname change.
sed -i 's/^DHCLIENT_FQDN_UPDATE=.*/DHCLIENT_FQDN_UPDATE="both"/' /etc/sysconfig/network/dhcp
# Do not let DHCP set hostname, this is set by cloud-init.
sed -i 's/^DHCLIENT_SET_HOSTNAME=.*/DHCLIENT_SET_HOSTNAME="no"/' /etc/sysconfig/network/dhcp
# Do not set default route, allow cloud-init to customize that.
sed -i 's/^DHCLIENT_SET_DEFAULT_ROUTE=.*/DHCLIENT_SET_DEFAULT_ROUTE="no"/' /etc/sysconfig/network/dhcp
