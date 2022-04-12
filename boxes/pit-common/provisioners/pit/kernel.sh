#!/bin/bash

set -ex

KERNEL_PACKAGES=(kernel-default-devel-"$SLES15_KERNEL_VERSION"
kernel-default-"$SLES15_KERNEL_VERSION")

# Clean-up all kernel-default packages.
zypper --non-interactive remove $(rpm -qa | grep kernel-default)

# Install desired kernel packages.
eval zypper --plus-content debug --non-interactive install --no-recommends --oldpackage "${KERNEL_PACKAGES[*]}"

# Ensure that only the desired kernel version may be installed.
sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf

# Clean up old kernels, if any. We should only ship with a single kernel.
zypper --non-interactive purge-kernels --details

# Lock the kernel to prevent inadvertent updates.
zypper addlock kernel-default

zypper ll

rpm -qa | grep kernel-default
