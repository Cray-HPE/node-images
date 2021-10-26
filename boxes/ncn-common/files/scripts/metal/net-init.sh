#!/bin/sh

set +e # Yes. This is a +e; this script is allowed to error.
printf 'net-init: [ % -20s ]\n' 'starting net-init'

printf 'net-init: [ % -20s ]\n' 'running: sysconfig'
cloud-init query --format="$(cat /etc/cloud/templates/cloud-init-network.tmpl)" >/etc/cloud/cloud.cfg.d/00_network.cfg

printf 'net-init: [ % -20s ]\n' 'running: netconfig'
# FIXME: MTL-1439 Use the default resolv_conf module.
sed -i 's/NETCONFIG_DNS_POLICY=.*/NETCONFIG_DNS_POLICY=""/g' /etc/sysconfig/network/config
# CASMTRIAGE-2521 - Break resolv.conf symlink to /run/netconf so cloud-init change persists across reboot.
if [[ -f /etc/resolv.conf ]]; then
    rm /etc/resolv.conf
fi
cloud-init query --format="$(cat /etc/cloud/templates/resolv.conf.tmpl)" >/etc/resolv.conf
# Cease updating the default route; use the templated config files.
sed -i 's/^DHCLIENT_SET_DEFAULT_ROUTE=.*/DHCLIENT_SET_DEFAULT_ROUTE="no"/' /etc/sysconfig/network/dhcp
netconfig update -f

# FIXME: MTL-1440 Use the default update_etc_hosts module.
printf 'net-init: [ % -20s ]\n' 'running: hosts file'
cloud-init query --format="$(cat /etc/cloud/templates/hosts.suse.tmpl)" >/etc/hosts

printf 'net-init: [ % -20s ]\n' 'running: acclimating'
# Run cloud-init again against our new network.cfg file.
cloud-init clean
cloud-init init

# Load our new configurations, or reload the daemon if nothing states it needs to be reloaded.
printf 'net-init: [ % -20s ]\n' 'running: ifreload'
wicked ifreload all || systemctl restart wicked

printf 'net-init: [ % -20s ]\n' 'completed'
