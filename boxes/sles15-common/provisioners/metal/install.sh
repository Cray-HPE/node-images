#!/bin/bash

set -e

echo "Enabling sysstat service for metal only"
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

