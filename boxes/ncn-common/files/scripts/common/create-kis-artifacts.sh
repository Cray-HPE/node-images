#!/bin/bash

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

# NOTE: it might seem like these KIS scripts belong in a metal subdir instead of common
# but the idea is that other environments, cloud ones even may soon IPXE boot squashfs
# NCNs for the sake of parity.

set -ex

mkdir -p /mnt/squashfs /squashfs
mount -o bind / /mnt/squashfs

# NOTE: These may be ran on a system; on a PIT or NCN node. Locking the kernel will assist
#       in chroot envs with newer kernels.
version_full=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-default)
version_base=${version_full%%-*}
version_suse=${version_full##*-}
version_suse=${version_suse%.*.*}
version="$version_base-$version_suse-default"

if [[ "$1" != "squashfs-only" ]]; then
  echo "Creating initrd/kernel artifacts"
  kernel_version="$(ls -1tr /boot/vmlinuz-* | tail -n 1 | cut -d '-' -f2,3,4)"
  mkdir -p /mnt/squashfs/proc /mnt/squashfs/run /mnt/squashfs/dev /mnt/squashfs/sys /mnt/squashfs/var
  mount --bind /proc /mnt/squashfs/proc
  mount --bind /tmp /mnt/squashfs/run
  mount --bind /dev /mnt/squashfs/dev
  mount --bind /sys /mnt/squashfs/sys
  mount --bind /var /mnt/squashfs/var
  [ -f /var/adm/autoinstall/cache ] && rm -rf /var/adm/autoinstall/cache || echo >&2 'Could not remove autoinstall/cache!'
  chroot /mnt/squashfs /bin/bash -c "dracut --xz --force \
    --omit 'cifs ntfs-3g btrfs nfs fcoe iscsi modsign fcoe-uefi nbd dmraid multipath dmsquash-live-ntfs' \
    --omit-drivers 'ecb md5 hmac' \
    --add 'mdraid' \
    --force-add 'dmsquash-live livenet mdraid' \
    --install 'rmdir wipefs sgdisk vgremove less' \
    --persistent-policy by-label --show-modules --ro-mnt --no-hostonly --no-hostonly-cmdline \
    --kver ${version} \
    --printsize /tmp/initrd.img.xz"
  cp /mnt/squashfs/boot/vmlinuz-${kernel_version} /squashfs/vmlinuz.kernel
  cp /mnt/squashfs/tmp/initrd.img.xz /squashfs/initrd.img.xz
  umount /mnt/squashfs/proc /mnt/squashfs/dev /mnt/squashfs/run /mnt/squashfs/sys /mnt/squashfs/var
fi

if [[ "$1" != "kernel-initrd-only" ]]; then
  echo "Creating squashfs artifact"
  mksquashfs /mnt/squashfs /squashfs/filesystem.squashfs -no-xattrs -comp gzip -no-exports -noappend -no-recovery -processors $(nproc) -e /mnt/squashfs/squashfs/filesystem.squashfs
fi
