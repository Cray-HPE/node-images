#!/bin/bash

set -e

echo "Etching release file"
zypper removelock kernel-default || echo 'No lock to remove'
zypper -n install --auto-agree-with-licenses --force-resolution SLE_HPC-release
zypper addlock kernel-default

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
ams || true

# Setup the bootloader.
sed -e '/^\s*GRUB_CMDLINE_LINUX_DEFAULT=/s/="[^"]*"/="splash=silent mediacheck=0 biosdevname=1 console=tty0 console=ttyS0,115200 mitigations=auto iommu=pt pcie_ports=native transparent_hugepage=never rd.shell rd.md=0 rd.md.conf=0"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# Allow domains.
sed -i 's/^DHCLIENT_FQDN_ENABLED=.*/DHCLIENT_FQDN_ENABLED="enabled"/' /etc/sysconfig/network/dhcp
# Notify update on hostname change.
sed -i 's/^DHCLIENT_FQDN_UPDATE=.*/DHCLIENT_FQDN_UPDATE="both"/' /etc/sysconfig/network/dhcp
# Do not let DHCP set hostname, this is set by cloud-init.
sed -i 's/^DHCLIENT_SET_HOSTNAME=.*/DHCLIENT_SET_HOSTNAME="no"/' /etc/sysconfig/network/dhcp
