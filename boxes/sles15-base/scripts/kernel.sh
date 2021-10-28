#!/bin/bash

set -ex

SLES15_KERNEL_VERSION="5.3.18-59.19.1"

KERNEL_PACKAGES=(kernel-default-debuginfo-"$SLES15_KERNEL_VERSION"
kernel-default-devel-"$SLES15_KERNEL_VERSION"
kernel-default-debugsource-"$SLES15_KERNEL_VERSION"
kernel-default-"$SLES15_KERNEL_VERSION")

zypper --non-interactive remove $(rpm -qa | grep kernel-default)
eval zypper --plus-content debug --non-interactive install --no-recommends --oldpackage "${KERNEL_PACKAGES[*]}"
sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf
zypper --non-interactive purge-kernels --details
zypper addlock kernel-default

zypper ll

rpm -qa | grep kernel-default