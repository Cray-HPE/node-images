#!/bin/bash

set -ex

KERNEL_PACKAGES=(kernel-default-debuginfo-"$SLES15_KERNEL_VERSION"
kernel-default-debugsource-"$SLES15_KERNEL_VERSION")

eval zypper --plus-content debug --non-interactive install --no-recommends --oldpackage "${KERNEL_PACKAGES[*]}"