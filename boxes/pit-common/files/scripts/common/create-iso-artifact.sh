#!/bin/bash
trap deactivate

echo >&2 This is not ready yet.
exit 1

# TODO: these are translated from kiwi source/output, a majority are probably not needed.
# TODO: we really need to just make a bootloader in a folder and then run xorriso.
# TODO: xorriso will need to know to fetch the bootloader folder we make and a few other properties of it.
# Creating grub2 bootloader images
mkdir -p /build/EFI/BOOT
# --> Creating identifier file 0xd3b477b3
mkdir -p /build/boot/grub2
mkdir -p /build/boot/x86_64/loader/grub2/fonts
cp /build/build/image-root/usr/share/grub2/unicode.pf2 /build/boot/x86_64/loader/grub2/fonts
mkdir -p /build/boot/grub2/themes
rsync -a --exclude /*.module /build/build/image-root/usr/share/grub2/i386-pc/ /build/boot/grub2/i386-pc
# --> Creating bios image
if (
    grub2-mkimage -O i386-pc -o /build/build/image-root/usr/share/grub2/i386-pc/core.img -c /build/boot/grub2/earlyboot.cfg -p /boot/grub2 -d /build/build/image-root/usr/share/grub2/i386-pc ext2 iso9660 linux echo configfile search_label search_fs_file search search_fs_uuid ls normal gzio png fat gettext font minicmd gfxterm gfxmenu all_video xfs btrfs lvm luks gcry_rijndael gcry_sha256 gcry_sha512 crypto cryptodisk test true loadenv part_gpt part_msdos biosdisk vga vbe chain boot
        cat /build/build/image-root/usr/share/grub2/i386-pc/cdboot.img /build/build/image-root/usr/share/grub2/i386-pc/core.img > /build/build/image-root/usr/share/grub2/i386-pc/eltorito.img
        rsync -a --exclude /*.module /build/build/image-root/usr/share/grub2/x86_64-efi/ /build/boot/grub2/x86_64-efi
        ); then
    cp /build/build/image-root/usr/share/efi/x86_64/shim.efi /build/EFI/BOOT/bootx64.efi
        cp /build/build/image-root/usr/share/efi/x86_64/grub.efi /build/EFI/BOOT
    fi
mkdir -p /build/build/image-root/image/loader/
# Copying loader files to /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/grub2/i386-pc/eltorito.img /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/grub2/i386-pc/boot_hybrid.img /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/syslinux/isolinux.bin /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/syslinux/gfxboot.c32 /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/syslinux/menu.c32 /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/syslinux/chain.c32 /build/build/image-root/image/loader/
cp -pv /build/build/image-root/usr/share/syslinux/mboot.c32 /build/build/image-root/image/loader/
cp /build/build/image-root/boot/memtest* /build/build/image-root/image/loader/memtest
rsync -a /build/build/image-root/image/loader/ /build/boot/x86_64/loader
# Writing grub2 defaults file
# TODO: Add the following kernel line:
# payload=file://dev/sda3 splash=silent mediacheck=0 biosdevname=1 console=tty0 console=ttyS0,115200 mitigations=auto iommu=pt pcie_ports=native transparent_hugepage=never rd.shell rd.md=0 rd.md.conf=0"
# Creating grub2 live ISO config file
qemu-img create /build/boot/x86_64/efi 15M
mkdosfs -n BOOT /build/boot/x86_64/efi
mcopy -Do -s -i /build/boot/x86_64/efi /build/EFI :
chroot /build/build/image-root dracut --verbose --no-hostonly --no-hostonly-cmdline --xz --install /.profile --add  kiwi-live pollcdrom  --omit  multipath  cray-pre-install-toolkit-sle15sp3.x86_64-CRAY.VERSION.HERE.initrd.xz 5.3.18-150300.59.63-default
mv /build/build/image-root/cray-pre-install-toolkit-sle15sp3.x86_64-CRAY.VERSION.HERE.initrd.xz /build
# Setting up kernel file(s) and boot image in ISO boot layout
cp /build/build/image-root/boot/vmlinuz-5.3.18-150300.59.63-default /build/boot/x86_64/loader//linux
du -s --apparent-size --block-size 1 --exclude /build/proc --exclude /build/sys --exclude /build/dev /build
# Packing system into dracut live ISO type: overlay
du -s --apparent-size --block-size 1 --exclude /build/build/image-root/proc --exclude /build/build/image-root/sys --exclude /build/build/image-root/dev /build/build/image-root
bash -c find /build/build/image-root | wc -l
# Using calculated size: 6678 MB
qemu-img create /tmp/tmp9qyyycwm 6678M
losetup -f --show /tmp/tmp9qyyycwm
mkfs.ext4 /dev/loop0
# --> Syncing data to ext4 root image
mountpoint -q /tmp/kiwi_mount_manager._x97ovxa
mount /dev/loop0 /tmp/kiwi_mount_manager._x97ovxa
rsync -a -H -X -A --one-file-system --inplace --exclude /image --exclude /.profile --exclude /.kconfig --exclude /.buildenv --exclude /var/cache/kiwi /build/build/image-root/ /tmp/kiwi_mount_manager._x97ovxa
# umount FileSystemExt4 instance
mountpoint -q /tmp/kiwi_mount_manager._x97ovxa
umount /tmp/kiwi_mount_manager._x97ovxa
mountpoint -q /tmp/kiwi_mount_manager._x97ovxa
rm -r -f /tmp/kiwi_mount_manager._x97ovxa
# --> Creating squashfs container for root image
mkdir -p /build/live-container.8wkxgoze/LiveOS
mksquashfs /build/live-container.8wkxgoze /tmp/tmptwgo7val -noappend -b 1M -comp xz -Xbcj x86
mkdir -p /build/LiveOS

# Use signing key
# TODO: Verify if this is needed, this is done in the existing kiwi-ng run.
wget https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc
# TODO Invoke kiwi-ng
ln -s --no-target-directory ../../usr/lib/sysimage/rpm /var/lib/rpm
rpm --import HPE-SHASTA-RPM-PROD.asc --dbpath /usr/lib/sysimage/rpm

# Build ISO.
/usr/bin/xorriso -application_id 0xd3b477b3 \
    -publisher CRAY-HPE \
    -preparer_id CRAY - https://github.com/Cray-HPE/node-image-build \
    -volid CRAYLIVE \
    -joliet on \
    -padding 0 \
    -outdev /build/cray-pre-install-toolkit-sle15sp3.x86_64-CRAY.VERSION.HERE.iso \
    -chmod 0755 / -- \
    -boot_image grub bin_path=boot/x86_64/loader/eltorito.img \
    -boot_image grub grub2_mbr=/build/boot/x86_64//loader/boot_hybrid.img \
    -boot_image grub grub2_boot_info=on \
    -boot_image any partition_offset=16 \
    -boot_image any cat_path=boot/x86_64/boot.catalog \
    -boot_image any cat_hidden=on \
    -boot_image any boot_info_table=on \
    -boot_image any platform_id=0x00 \
    -boot_image any emul_type=no_emulation \
    -boot_image any load_size=2048 \
    -append_partition 2 0xef /build/boot/x86_64/efi \
    -boot_image any next \
    -boot_image any efi_path=--interval:appended_partition_2:all:: \
    -boot_image any platform_id=0xef \
    -boot_image any emul_type=no_emulation
tagmedia --md5 --check --pad 150 /build/cray-pre-install-toolkit-sle15sp3.x86_64-CRAY.VERSION.HERE.iso
# --profile=PITISO --type iso --debug system build --description $DESC_DIR --target-dir /build --signing-key HPE-SHASTA-RPM-PROD.asc
