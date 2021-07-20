#!/bin/bash

# this script can either be called at runtime coupled with a network restart
# or as part of a build at a topmost layer. If it's called at any lower layer build, the build
# network for layers above will be broken

# FIXME: This should copy a file into the image, instead of on-the-fly replacing.
# Allow domains.
sed -i 's/^DHCLIENT_FQDN_ENABLED=.*/DHCLIENT_FQDN_ENABLED="enabled"/' /etc/sysconfig/network/dhcp
# Notify update on hostname change.
sed -i 's/^DHCLIENT_FQDN_UPDATE=.*/DHCLIENT_FQDN_UPDATE="both"/' /etc/sysconfig/network/dhcp
# Do not let DHCP set hostname, this is set by cloud-init.
sed -i 's/^DHCLIENT_SET_HOSTNAME=.*/DHCLIENT_SET_HOSTNAME="no"/' /etc/sysconfig/network/dhcp
# Do not set default route, allow cloud-init to customize that.
sed -i 's/^DHCLIENT_SET_DEFAULT_ROUTE=.*/DHCLIENT_SET_DEFAULT_ROUTE="no"/' /etc/sysconfig/network/dhcp
