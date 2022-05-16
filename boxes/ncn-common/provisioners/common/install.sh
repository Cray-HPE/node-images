#!/bin/bash

set -ex

# Ensure that only the desired kernel version may be installed.
# Clean up old kernels, if any. We should only ship with a single kernel.
# Lock the kernel to prevent inadvertent updates.
function kernel {
    local sles15_kernel_version
    sles15_kernel_version=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}\n" kernel-default)

    echo "Purging old kernels ... "
    sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf
    zypper --non-interactive purge-kernels --details

    echo "Locking the kernel to $SLES15_KERNEL_VERSION"
    zypper addlock kernel-default

    echo 'Listing locks and kernel RPM(s)'
    zypper ll
    rpm -qa | grep kernel-default
}
kernel

# Disable undesirable kernel modules
function kernel_modules {
    local disabled_modules="libiscsi"
    local modprobe_file=/etc/modprobe.d/disabled-modules.conf

    touch $modprobe_file

    for mod in $disabled_modules; do
        echo "install $mod /bin/true" >> $modprobe_file
    done
}
kernel_modules
