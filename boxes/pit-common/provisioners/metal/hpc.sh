#!/bin/sh

# HPC metal clusters reflect their nature through the SLES HPC Release RPM.
# The conflicting RPM needs to be removed
# Forcing the the HPC rpm because removing sles-release auto removes dependencies
# even with -U when installing with inventory file
set -ex

echo "Etching release file"
zypper removelock kernel-default || echo 'No lock to remove'
zypper -n install --auto-agree-with-licenses --force-resolution SLE_HPC-release
zypper addlock kernel-default
