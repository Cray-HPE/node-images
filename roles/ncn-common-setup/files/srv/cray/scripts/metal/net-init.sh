#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

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
    local gw
    local nic=bond0.cmn0

    # Render the template
    printf 'net-init: [ % -20s ]\n' 'running: sysconfig'
    cloud-init query --format="$(cat /etc/cloud/templates/cloud-init-network.tmpl)" >/etc/cloud/cloud.cfg.d/00_network.cfg || fail_and_die "cloud-init query failed to render cloud-init-network.tmpl"
    printf 'net-init: [ % -20s ]\n' 'running: acclimating'

    # PHASE 1: Invoke the generated template; generate the ifcfg files
    cloud-init clean
    cloud-init init

    # Print diagnostic info
    ip r
    ip a show mgmt0
    ip a show mgmt1

    gw=$(craysys metadata get --level node ipam | jq .cmn.gateway | tr -d '"')
    if [ "$gw" = "" ]; then
        echo "FATAL ERROR: unable to determine default route via craysys"
        exit 1
    else
        echo "default ${gw} - $nic" >/etc/sysconfig/network/ifroute-$nic
    fi

    # removing eth0 configs
    # ALWAYS DO THIS; THESE SHOULD NOT EXIST IN METAL
    # Any interface file that exists is tracked by wicked, if the interface does
    # not actually exist in reality then wicked will complain. Remove the needless files.
    rm -rfv /etc/sysconfig/network/*eth*

    printf 'net-init: [ % -20s ]\n' 'running: ifreload'
    # Load our new configurations, or reload the daemon if nothing states it needs to be reloaded.
    wicked ifreload all || systemctl restart wickedd
    printf 'net-init: [ % -20s ]\n' 'running: acclimating'

    sleep 10

    # Print diagnostic info
    ip r
    ip a show mgmt0
    ip a show mgmt1
    ip a show bond0

    unenslavednic=$(ip a | grep -v SLAVE | awk -F': ' /mgmt[01]/'{print $2}')
    if [[ "$unenslavednic" =~ mgmt ]]; then
        printf 'net-init: [ % -20s ]\n' 'repairing bond0'
        ip link set $unenslavednic down
        ip link set $unenslavednic master bond0
    fi
    ip a | grep bond

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

function iptables_config() {
    mkdir -p /etc/iptables/

    if [[ -f /etc/iptables/metal.conf ]]; then
       rm /etc/iptables/metal.conf
    fi

    # Render the template
    printf 'net-init: [ % -20s ]\n' 'running: iptables_config'
    cloud-init query --format="$(cat /etc/cloud/templates/metal-iptables.conf.tmpl)" >/etc/iptables/metal.conf || fail_and_die "cloud-init query failed to render metal-iptables.conf.tmpl"

    printf 'net-init: [ % -20s ]\n' 'running: metal-iptables restart'
    systemctl enable metal-iptables
    systemctl restart metal-iptables
}
iptables_config

printf 'net-init: [ % -20s ]\n' 'completed'
