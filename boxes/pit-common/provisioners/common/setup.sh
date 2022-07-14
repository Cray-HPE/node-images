#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
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
set -e

#======================================
# Set hostname to pit
#--------------------------------------
echo 'pit' > /etc/hostname

#======================================
# Force root user to change password
# at first login.
#--------------------------------------
chage -d 0 root

#======================================
# Goss is used to validate LiveCD health
# at builds, installs and runtime.
#--------------------------------------
echo "Create symlinks for automated preflight checks"
GOSS_BASE=/opt/cray/tests/install/livecd
ln -s $GOSS_BASE/automated/livecd-preflight-checks /usr/bin/livecd-preflight-checks
ln -s $GOSS_BASE/automated/ncn-preflight-checks /usr/bin/ncn-preflight-checks
ln -s $GOSS_BASE/automated/ncn-kubernetes-checks /usr/bin/ncn-kubernetes-checks
ln -s $GOSS_BASE/automated/ncn-storage-checks /usr/bin/ncn-storage-checks

#======================================
# Make packer directories
#--------------------------------------
echo "Initializing directories and resources"
mkdir -pv /srv/cray
cp -prv /tmp/files/* /srv/cray/ && rm -rf /tmp/files
find /srv/cray/scripts -type f -name *.sh -exec chmod +x {} \+

#======================================
# Copy resources
#--------------------------------------
cp -rpv /srv/cray/resources/common/etc /
cp -rpv /srv/cray/resources/common/usr /
cp -rpv /srv/cray/resources/common/var /

#======================================
# Write the pre-install-toolkit version 
# file. Build from the env (Jenkins)
# or build from the local-build repo.
#--------------------------------------
echo "Making /etc/pit-release"
if [[ -z $PIT_SLUG ]]; then
  export PIT_VERSION=$(git describe --tags --abbrev=0)
  export PIT_TIMESTAMP=$(date -u '+%Y%m%d%H%M%S')
  export PIT_HASH=$(git log -n 1 --pretty=format:'%h')
else
  export PIT_VERSION=$(echo $PIT_SLUG | cut -d '/' -f1)
  export PIT_TIMESTAMP=$(echo $PIT_SLUG | cut -d '/' -f2)
  export PIT_HASH=$(echo $PIT_SLUG | cut -d '/' -f3)
fi
cat << EOF > /etc/pit-release
VERSION=$PIT_VERSION
TIMESTAMP=$PIT_TIMESTAMP
HASH=$PIT_HASH
EOF
cat /etc/pit-release
