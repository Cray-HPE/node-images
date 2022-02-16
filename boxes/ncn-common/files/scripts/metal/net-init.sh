#!/bin/bash

# don't complain about unquoted vars / word splitting
# shellcheck disable=SC2086

function fail_and_die() {
    echo >&2 "${1:-"$0 failed and is exiting"}"
    exit 1
}

set +e # Yes. This is a +e; this script is allowed to error.
printf 'net-init: [ % -20s ]\n' 'starting net-init'

printf 'net-init: [ % -20s ]\n' 'running: netconfig'
# FIXME: MTL-1439 Use the default resolv_conf module.
sed -i 's/NETCONFIG_DNS_POLICY=.*/NETCONFIG_DNS_POLICY=""/g' /etc/sysconfig/network/config
# CASMTRIAGE-2521 - Break resolv.conf symlink to /run/netconf so cloud-init change persists across reboot.
if [[ -f /etc/resolv.conf ]]; then
    rm /etc/resolv.conf
fi
cloud-init query --format="$(cat /etc/cloud/templates/resolv.conf.tmpl)" >/etc/resolv.conf || fail_and_die "cloud-init query failed to render resolv.conf.tmpl"
# Cease updating the default route; use the templated config files.
sed -i 's/^DHCLIENT_SET_DEFAULT_ROUTE=.*/DHCLIENT_SET_DEFAULT_ROUTE="no"/' /etc/sysconfig/network/dhcp
netconfig update -f

# FIXME: MTL-1440 Use the default update_etc_hosts module.
printf 'net-init: [ % -20s ]\n' 'running: hosts file'
cloud-init query --format="$(cat /etc/cloud/templates/hosts.suse.tmpl)" >/etc/hosts || fail_and_die "cloud-init query failed to render hosts.suse.tmpl"

# This function runs cloud-init commands twice;
# once to generate the ifcfg files,
# and again to reload cloud-init metadata after network daemons restart.
function ifconf() {
    # Render the template
    printf 'net-init: [ % -20s ]\n' 'running: sysconfig'
    cloud-init query --format="$(cat /etc/cloud/templates/cloud-init-network.tmpl)" >/etc/cloud/cloud.cfg.d/00_network.cfg || fail_and_die "cloud-init query failed to render cloud-init-network.tmpl"
    printf 'net-init: [ % -20s ]\n' 'running: acclimating'

    # PHASE 1: Invoke the generated template; generate the ifcfg files
    cloud-init clean
    cloud-init init

    # FIXME: Understand why cloud-init doesn't fix this for us; what is "Running interface command ['systemctl', 'restart', 'systemd-networkd', 'systemd-resolved'] failed"
    # Load our new configurations, or reload the daemon if nothing states it needs to be reloaded.
    printf 'net-init: [ % -20s ]\n' 'running: ifreload'
    wicked ifreload all

    # PHASE 2: cloud-init local meta will be invalid now that our topology changed; re-init cloud-init
    cloud-init clean
    cloud-init init
}
ifconf

# Checks whether IPs exist on all of our NICs or not.
function check_ips() {
    local flunk=${1:-0}
    # only fetch IPs for our networks
    for nic in /etc/sysconfig/network/ifcfg-bond*.*; do
        ipv4_lease=$(wicked ifstatus --verbose ${nic#*-} | grep addr | grep ipv4)
        # shellcheck disable=SC2076
        # Intentional quotes. This is not a regex.
        if [[ "$ipv4_lease" =~ "[static]" ]]; then
            :
         else
            error=1
        fi
    done
    [ "$flunk" != 0 ] && [ "$error" != 0 ] &&  return 1
    return 0
}
printf 'net-init: [ % -20s ]\n' 'testing: static IPs'
check_ips
if [ ${error:-0} != 0 ]; then
    printf 'net-init: [ % -20s ]\n' 'quiesce: wickedd'
    systemctl restart wickedd-nanny
fi
# Sleep for 2 seconds to let wickedd-nanny startup, and then restart the
# child-process specific to NIC handlers so they force loading the new configs.
sleep 2
if check_ips 1 ; then
    printf 'net-init: [ % -20s ]\n' 'testing: failed!'
else
    printf 'net-init: [ % -20s ]\n' 'testing: IPs exist'
fi
printf 'net-init: [ % -20s ]\n' 'completed'
