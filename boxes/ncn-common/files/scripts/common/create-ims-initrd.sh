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

# This script does not use bind mounts and thus executes correctly in a container
set -e
set -x

echo "Generating initrd..."

version_full=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-default)
version_base=${version_full%%-*}
version_suse=${version_full##*-}
version_suse=${version_suse%.*.*}
version="$version_base-$version_suse-default"

dracut \
--force \
--omit 'cifs ntfs-3g btrfs nfs fcoe iscsi modsign fcoe-uefi nbd dmraid multipath dmsquash-live-ntfs' \
--omit-drivers 'ecb md5 hmac' \
--add 'mdraid' \
--force-add 'dmsquash-live livenet mdraid' \
--kver ${version} \
--no-hostonly \
--no-hostonly-cmdline \
--printsize \
--xz \
/boot/initrd-${version}

exit 0
