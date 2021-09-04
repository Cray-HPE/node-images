#!/bin/sh
set -e
cloud-init query --format="$(cat /etc/cloud/templates/cloud-init-network.tmpl)" >/etc/cloud/cloud.cfg.d/00_network.cfg

# FIXME: MTL-1439 Use the default resolv_conf module.
sed -i 's/NETCONFIG_DNS_POLICY=.*/NETCONFIG_DNS_POLICY=""/g' /etc/sysconfig/network/config
cloud-init query --format="$(cat /etc/cloud/templates/resolv.conf.tmpl)" > /etc/resolv.conf

# FIXME: MTL-1440 Use the default update_etc_hosts module.
cloud-init query --format="$(cat /etc/cloud/templates/hosts.suse.tmpl)" > /etc/hosts

# Cease updating the default route; use the templated config files.
sed -i 's/^DHCLIENT_SET_DEFAULT_ROUTE=.*/DHCLIENT_SET_DEFAULT_ROUTE="no"/' /etc/sysconfig/network/dhcp
netconfig update -f

# Run cloud-init again against our new network.cfg file.
cloud-init clean
cloud-init init

# Load our new configurations, or reload the daemon if nothing states it needs to be reloaded.
wicked ifreload all || systemctl restart wicked
