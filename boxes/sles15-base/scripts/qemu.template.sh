#!/bin/bash

set -ex

# install required packages
packages=( jq )
zypper --non-interactive install --no-recommends --force-resolution "${packages[@]}"

rpm -qa | grep kernel-default

KERNEL_PACKAGES=(kernel-default-debuginfo-"$SLES15_KERNEL_VERSION"
kernel-default-devel-"$SLES15_KERNEL_VERSION"
kernel-default-debugsource-"$SLES15_KERNEL_VERSION"
kernel-default-"$SLES15_KERNEL_VERSION")

# kernel-default-devel is not installed in the base ISO
zypper --non-interactive remove kernel-default kernel-default-debugsource kernel-default-debuginfo

eval zypper --non-interactive install --no-recommends --oldpackage "${KERNEL_PACKAGES[*]}"

zypper addlock kernel-default

zypper ll

rpm -qa | grep kernel-default
