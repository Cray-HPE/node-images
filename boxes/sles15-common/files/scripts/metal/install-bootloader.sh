#!/bin/bash
# Copyright 2020 HPED LP
fslabel=BOOTRAID
working_path=/metal/recovery
trap 'umount -v $working_path && rmdir -f /tmp/mount 2>/dev/null && echo && exit 0' EXIT

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

function update_auxiliary_fstab {
    # Mount at boot
    if [ -f /etc/fstab.metal ] && grep -q "${fslabel^^}" /etc/fstab.metal; then :
    else
        mkdir -pv $working_path
        printf '# \nLABEL=%s\t%s\t%s\t%s\t%d\t%d\n' "${fslabel^^}" $working_path vfat defaults 0 0 >> /etc/fstab.metal
    fi
}

function get_boot_artifacts {
    # TODO: Grab rd.live.dir from cmdline and remove LiveOS hardcode.
    local squashfs_storage
    local initrd
    local base_dir
    local live_dir
    local artifact_error=0

    squashfs_storage=$(grep -Po 'root=\w+:?\w+=\w+' /proc/cmdline | cut -d '=' -f3)
    [ -z "$squashfs_storage" ] && squashfs_storage=SQFSRAID

    # initrd - fetched from /proc/cmdline ; grab the horse we rode in on, not what the API aliens say.
    initrd=$(grep -Po 'initrd=([\w\.]+)' /proc/cmdline | cut -d '=' -f2)
    [ -z "$initrd" ] && initrd=initrd.img.xz

    # rd.live.dir - fetched from /proc/cmdline ; grab any customization or deviation from the default preference, aling with dracut.
    live_dir=$(grep -Eo 'rd.live.dir=.* ' /proc/cmdline | cut -d '=' -f2 | sed 's![^/]$!&/!')
    [ -z "$live_dir" ] && live_dir=LiveOS/

    # pull the loaded items from the mounted squashFS storage into the fallback bootloader
    base_dir="$(lsblk $(blkid -L $squashfs_storage) -o MOUNTPOINT -n)/$live_dir"
    [ -d $base_dir ] || echo >&2 'SQFSRAID was not mounted!' return 1
    cp -pv "${base_dir}kernel" "$working_path/boot/" || echo >&2 "Kernel file NOT found in $base_dir!" && artifact_error=1
    cp -pv "${base_dir}${initrd}" "$working_path/boot/" || echo >&2 "${initrd} file NOT found in $base_dir!" && artifact_error=1

    [ "$artifact_error" = 0 ] && return 0 || return 1
}

update_auxiliary_fstab
get_boot_artifacts