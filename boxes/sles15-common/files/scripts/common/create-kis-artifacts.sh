#!/usr/bin/env bash

# NOTE: it might seem like these KIS scripts belong in a metal subdir instead of common
# but the idea is that other environments, cloud ones even may soon IPXE boot squashfs
# NCNs for the sake of parity.

set -e

mkdir -p /mnt/squashfs /squashfs
mount -o bind / /mnt/squashfs

# NOTE: These may be ran on a system; on a PIT or NCN node. Locking the kernel will assist
#       in chroot envs with newer kernels.
version_full=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-default)
version_base=${version_full%%-*}
version_suse=${version_full##*-}
version_suse=${version_suse%.*.*}
version="$version_base-$version_suse-default"
initrd_name="/boot/initrd-$version-dev"

if [[ "$1" != "squashfs-only" ]]; then
  echo "Creating initrd/kernel artifacts"
  kernel_version="$(echo /mnt/squashfs/boot/vmlinuz-* | sed -e 's:/mnt/squashfs/boot/vmlinuz-::')"
  mkdir -p /mnt/squashfs/proc /mnt/squashfs/run /mnt/squashfs/dev /mnt/squashfs/sys
  mount --bind /proc /mnt/squashfs/proc
  mount --bind /tmp /mnt/squashfs/run
  mount --bind /dev /mnt/squashfs/dev
  mount --bind /sys /mnt/squashfs/sys
  chroot /mnt/squashfs /bin/bash -c "dracut --xz --force \
    --omit 'cifs ntfs-3g btrfs nfs fcoe iscsi modsign fcoe-uefi nbd dmraid multipath dmsquash-live-ntfs' \
    --omit-drivers 'ecb md5 hmac' \
    --add 'mdraid' \
    --force-add 'dmsquash-live livenet mdraid' \
    --install 'rmdir wipefs sgdisk vgremove less' \
    --persistent-policy by-label --show-modules --ro-mnt --no-hostonly --no-hostonly-cmdline \
    --kver ${version} \
    --printsize /tmp/initrd.img.xz"
  cp /mnt/squashfs/boot/vmlinuz-${kernel_version} /squashfs/${kernel_version}.kernel
  cp /mnt/squashfs/tmp/initrd.img.xz /squashfs/initrd.img.xz
  umount /mnt/squashfs/proc /mnt/squashfs/dev /mnt/squashfs/run /mnt/squashfs/sys
fi

if [[ "$1" != "kernel-initrd-only" ]]; then
  echo "Creating squashfs artifact"
  mksquashfs /mnt/squashfs /squashfs/filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery -processors $(nproc) -e /mnt/squashfs/squashfs/filesystem.squashfs
fi

( cd /squashfs && tar -cvzf /tmp/kis.tar.gz . )
