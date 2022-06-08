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
