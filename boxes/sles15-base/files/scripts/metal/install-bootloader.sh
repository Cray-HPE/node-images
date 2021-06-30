#!/bin/bash
# Copyright 2020 HPED LP
fslabel=BOOTRAID
working_path=/metal/recovery
trap 'umount -v $working_path && rmdir -f /tmp/mount 2>/dev/null && echo && exit 0' EXIT

# run before 'set -e' since this is not our library and it should work or die.
type getarg > /dev/null 2>&1 || . /usr/lib/dracut/modules.d/99base/dracut-lib.sh || alias getarg='echo initrd'

set -e

mkdir -pv $working_path
mount -v -L $fslabel $working_path || echo 'continuing ...'

trim() {
    local var="$*"
    var="${var#${var%%[![:space:]]*}}"   # remove leading whitespace characters
    var="${var%${var##*[![:space:]]}}"   # remove trailing whitespace characters
    printf "%s" "$var"
}

# Remove all existing ones; this script installs the only bootloader.
for entry in $(efibootmgr | awk -F '*' '/cray/ {print $1}'); do
     efibootmgr -q -b ${entry:4:8} -B
done

# Install grub2.
name=$(grep PRETTY_NAME /etc/*release* | cut -d '=' -f2 | tr -d '"')
vendor=$(ipmitool fru | grep -i 'board mfg' | tail -n 1 | cut -d ':' -f2 | tr -d ' ')
[ -z "$name" ] && name='CRAY Linux'
for disk in $(mdadm --detail $(blkid -L $fslabel) | grep /dev/sd | awk '{print $NF}'); do
    # Add '--suse-enable-tpm' to grub2-install once we need TPM.
    grub2-install --no-rs-codes --suse-force-signed --root-directory $working_path --removable "$disk"
    efibootmgr -c -D -d "$disk" -p 1 -L "cray ($(basename $disk))" -l '\efi\boot\bootx64.efi' | grep cray
done

# Get the kernel command we used to boot.
init_cmdline=$(cat /proc/cmdline)
disk_cmdline=''
for cmd in $init_cmdline; do
    # cleans up first argument when running this script on an grub-booted system
    if [[ $cmd =~ kernel$ ]]; then
        cmd=$(basename "$(echo $cmd  | awk '{print $1}')")
    fi
    # removes all metal vars, and escapes anything that iPXE was escaping
    # (i.e. ds=nocloud-net;s=http://$url will get the ; escaped)
    # removes netboot vars
    if [[ ! $cmd =~ ^metal. ]] && [[ ! $cmd =~ ^ip=.*:dhcp ]] && [[ ! $cmd =~ ^bootdev= ]]; then
        disk_cmdline="$(trim $disk_cmdline) ${cmd//;/\\;}"
    fi
done

# ensure no-wipe is now set for disk-boots.
disk_cmdline="$disk_cmdline metal.no-wipe=1"

# Make our grub.cfg file.
cat << EOF > $working_path/boot/grub2/grub.cfg
set timeout=10
set default=0 # Set the default menu entry
menuentry "$name" --class sles --class gnu-linux --class gnu {
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod diskfilter
    insmod mdraid1x
    insmod ext2
    insmod xfs
    echo	'Loading Linux  ...'
    linuxefi \$prefix/../$disk_cmdline domdadm
    echo	'Loading initial ramdisk ...'
    initrdefi \$prefix/../initrd.img.xz
}
EOF

# TODO: Grab rd.live.dir from cmdline and remove LiveOS hardcode.
base_dir="$(lsblk $(blkid -L SQFSRAID) -o MOUNTPOINT -n)/LiveOS"

if [ -f ${base_dir}/kernel ]
then
  cp -pv ${base_dir}/kernel $working_path/boot/
else
  echo "Kernel file NOT found in $base_dir!"
fi

if [ -f ${base_dir}/initrd.img.xz ]
then
  cp -pv ${base_dir}/initrd.img.xz $working_path/boot/
else
  echo "${initrd} file NOT found in $base_dir!"
fi

# Mount at boot
if [ -f /etc/fstab.metal ] && grep -q "${fslabel^^}" /etc/fstab.metal; then :
else
    mkdir -pv $working_path
    printf '# \nLABEL=%s\t%s\t%s\t%s\t%d\t%d\n' "${fslabel^^}" $working_path vfat defaults 0 0 >> /etc/fstab.metal
fi

exit 0
