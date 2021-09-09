#!/bin/sh
set -e
# Do cloud-init again, there is no try.
#
# This script will do two things:
# 1. It will force-configuration file creation and restart network daemons;
# killing all hanlders on network interfaces for a clean slate.
# 2. Run cloud-init without any tampering to standard run-protocol (e.g.
# enabling cloud-init, running the needful cloud-init commands, and then
# disabling cloud-init.

err_report() {
    echo "Error on line $1"
    # ensure cloud-init won't run on next boot
    touch /etc/cloud/cloud-init.disabled
    exit 1
}

trap 'err_report $LINENO' ERR

# Do this once and once only.
# NOTE: An admin reading this during trouble-shooting may want to consider
# re-running these two commands before re-attempting retry-ci.sh
#
#   systemctl restart wickedd-nanny && ip a
#
# If undesirables appear in the `ip a` output then do the next command (otherwise re-run
#   retry-ci.sh):
#  
#   systemctl restart wicked
#
# but subsequent times can reload wickedd-nanny
# handlers safely.
# If the provided commands fail, triage should be signaled or a bug report
# should be filed with the current TCP/IP information printed to console
# scrollback.
[ -f /tmp/dhcp-static-done-once-this-boot.done ] || /srv/cray/scripts/metal/set-dhcp-to-static.sh && echo 1 >/tmp/dhcp-static-done-once-this-boot.done

# These udev rules should always be removed; fixme: remove in dracut
rm -f /etc/udev/rules.d/*persistent-net-cloud-init* 2>/dev/null

# cloud-init; (re-)enabled
echo 'Running cloud-init'
rm -f /etc/cloud/cloud-init.disabled

# cloud-init; start
cloud-init clean
cloud-init init
cloud-init modules -m init
cloud-init modules -m config
cloud-init modules -m final

# cloud-init; disabled
touch /etc/cloud/cloud-init.disabled

echo 'Done'
