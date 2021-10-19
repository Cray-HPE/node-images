#!/bin/sh

# HPC metal clusters reflect their nature through the SLES HPC Releae RPM.
# The conflicting RPM needs to be removed
# Forcing the the HPC rpm because removing sles-release auto removes dependencies
# even with -U when installing with inventory file
set -e

echo "Etching release file"
HPC_VERSION=$(cat /srv/cray/csm-rpms/packages/node-image-non-compute-common/metal.packages | grep "SLE_HPC-release")
zypper -n install --auto-agree-with-licenses --force-resolution ${HPC_VERSION}
