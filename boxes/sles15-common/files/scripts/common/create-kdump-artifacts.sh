#!/usr/bin/env bash
# Copyright 2021 HPED LP
# create-kdump-artifacts.sh creates an initrd for use with kdump
#   this specialized initrd is booted when a node crashes
#   it is specifically designed to work with the persistent overlay and RAIDs in use in Shasta 1.4+
set -e

# show the line that we failed and on and exit non-zero
trap 'catch $? $LINENO; cleanup; exit 1' ERR
# if the script is interrupted, run the cleanup function
trap 'cleanup' INT

# catch() prints what line the script failed on, runs the cleanup function, and then exits non-zero
catch() {
  # Show what line the error occurred on because it can be difficult to detect in a dracut environment
  echo "CATCH: exit code $1 occurred on line $2 in $(basename "${0}")"
  cleanup
  exit 1
}

# cleanup() removes temporary files, puts things back where they belong, etc.
cleanup() {
  # Ensures things are unmounted via 'trap' even if the command fails
  echo "CLEANUP: cleanup function running..."
  # remove the temporary fstab file
  if [ -f $fstab_kdump ]; then
    rm -f $fstab_kdump
  fi

  # during the script this config causes complications with the dracut command
  # so it's moved out the way; this puts it back to where it belongs
  if [ -f /tmp/metalconf/05-metal.conf ]; then
    mv /tmp/metalconf/05-metal.conf /etc/dracut.conf.d/
  fi

  # the initrd is unpacked to modify some contents
  # it is removed here so we can have a clean run everytime the script runs
  if [ -d /tmp/ktmp/ ]; then
    rm -rf /tmp/ktmp/
  fi

  systemctl disable kdump-cray
}

# check_size() offers a CAUTION message if the initrd is larger then 20MB
# this is just a soft warning since several factors can influence running out of memory including:
# crashkernel= parameters, drivers that are loaded, modules that are loaded, etc.
# so it's more of a your mileage may vary message
check_size() {
  local initrd="$1"
  # kdump initrds larger than 20M may run into issues with memory
  if [[ "$(stat --format=%s $initrd)" -ge 20000000 ]]; then
    echo "CAUTION: initrd might be too large ($(stat --format=%s $initrd)) and may OOM if used"
  else
    echo "initrd size is $(stat --format=%s $initrd)"
  fi
}

# Get the current version of the kernel to craft the kdump initrd name/path
version_full=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-default)
version_base=${version_full%%-*}
version_suse=${version_full##*-}
version_suse=${version_suse%.*.*}
version="$version_base-$version_suse-default"
initrd_name="/boot/initrd-$version-kdump"

echo "Creating initrd/kernel artifacts..."
# These are blacklisted in the initrd, but depending on the situation, they can be completely removed if the initrd is too big
# echo "Excluding mellanox/infiniband drivers..."
# kdump_omit_drivers=""
# for n in $(find /lib/modules/*-default \( -name "*mellanox*.ko" -o -name "*mlx*.ko" -o -name "*infiniband*.ko" -o -name "*ib*.ko" \))
# do
#   k=$(basename $n)
#   ko=${k##/*/}
#   name=${k%.ko*}
#   kdump_omit_drivers+="$name "
# done
#
# echo "Excluding lustre drivers..."
# for n in $(find /lib/modules/*-default/updates/cray-lustre-client -name "*.ko")
# do
#   k=$(basename $n)
#   ko=${k##/*/}
#   name=${k%.ko*}
#   kdump_omit_drivers+="$name "
# done

# trim() is borrowed from dracut-functions
trim ()
{
  local var="$*";
  var="${var#${var%%[![:space:]]*}}";
  var="${var%${var##*[![:space:]]}}";
  printf "%s" "$var"
}

# get the current kernel parameters
init_cmdline=$(cat /proc/cmdline)
for cmd in $init_cmdline; do
    # grab only the raid, live, and root directives so we can use them in kdump
    if [[ $cmd =~ ^rd\.md.* ]] || [[ $cmd =~ ^rd\.live.* ]] || [[ $cmd =~ ^root.* ]] ; then
      cmd=$(basename "$(echo $cmd  | awk '{print $1}')")
      kdump_cmdline+="$cmd "
    fi
done

# Remove these un-needed drivers
kdump_omit_drivers+="ecb "
kdump_omit_drivers+="md5 "
kdump_omit_drivers+="hmac "
echo ">> kdump_omit_drivers=\"$kdump_omit_drivers\"" >/dev/null

# kdump-specific kernel parameters
# cmdline params required for kdump:
#    root
#    console
#    irqpoll
#    reset_devices
#    elevator=deadline
kdump_cmdline+="irqpoll "
kdump_cmdline+="nr_cpus=1 "
kdump_cmdline+="selinux=0 "
kdump_cmdline+="reset_devices "
kdump_cmdline+="cgroup_disable=memory "
kdump_cmdline+="mce=off "
kdump_cmdline+="numa=off "
kdump_cmdline+="udev.children-max=2 "
kdump_cmdline+="acpi_no_memhotplug "
kdump_cmdline+="rd.neednet=0 "
kdump_cmdline+="rd.shell "
kdump_cmdline+="panic=10 "
kdump_cmdline+="nohpet "
kdump_cmdline+="nokaslr "
kdump_cmdline+="transparent_hugepage=never "
# mellanox drivers need to be blacklisted in order to prevent OOM errors
kdump_cmdline+="rd.driver.blacklist=mlx5_core,mlx5_ib "
kdump_cmdline+="rd.info "
# adjust here if you want a break point
#kdump_cmdline+="rd.break=pre-mount "
# uncomment to see debug info when running in the kdump initrd
#kdump_cmdline+="rd.debug=1 "
echo ">> kdump_cmdline=\"$kdump_cmdline\"" >/dev/null

# modules to remove
kdump_omit+="plymouth "
kdump_omit+="resume "
kdump_omit+="usrmount "
kdump_omit+="haveged "
# the metal modules conflict and add extra complexity here so we remove them
# the kdump and raid modules handle everything we need:
#    discover RAID
#    mount squash
#    create overlay *handled by a custom pre-script
#    save the dump
#    reboot
# so all the logic in the metal modules are completely unnecessary
kdump_omit+="metaldmk8s "
kdump_omit+="metalluksetcd "
kdump_omit+="metalmdsquash "
echo ">> kdump_omit=\"$kdump_omit\"" >/dev/null

# This will be used in fstab and translate to /var/crash on the overlay when the node comes back up.
# This is also unique to each host and the disks it lands on
sqfs_uuid=$(blkid -lt LABEL=SQFSRAID | tr ' ' '\n' | awk -F '"' ' /UUID/ {print $2}')
# the above will be used in the fstab file used to facilitate mounting all the pieces we need for the overlay
fstab_kdump=/tmp/fstab.kdump

# mount the root raid
# mount the squashfs raid
# mount the squash image
# create the overlay with mount_kdump_overlay.sh
# a fstab entry could be used here, but it ran into issues, so the pre-script just runs a 'mount' commmand instead:
#        overlay /kdump/overlay overlay ro,relatime,lowerdir=/kdump/mnt2,upperdir=/kdump/mnt0/LiveOS/overlay-SQFSRAID-${sqfs_uuid},workdir=/kdump/mnt0/LiveOS/ovlwork 0 2
cat << EOF > "$fstab_kdump"
LABEL=ROOTRAID /kdump/mnt0/ xfs defaults 0 0
LABEL=SQFSRAID /kdump/mnt1/ xfs defaults 0 0
/kdump/mnt1/LiveOS/filesystem.squashfs /kdump/mnt2 squashfs ro,defaults 0 0
# overlay is mounted via mount_kdump_overlay.sh
EOF

# move the 05-metal.conf file out of the way while the initrd is generated
# it causes some conflicts if it's in place when 'dracut' is called
mkdir -p /tmp/metalconf
mv /etc/dracut.conf.d/05-metal.conf /tmp/metalconf/

# generate the kdump initrd
#   --hostonly trims down the size by keeping only what is needed for the specific host
#   --omit omits the modules we don't want from the list crafted earlier in the script
#   --tmpdir is needed to avoid an error where 'init is on a different filesystem' (overlay-related)
#   --install can be used to add other binaries to the environment.  This is useful for debug, but can also be removed if the initrd needs to be smaller
#   --force-drivers will add the driver even if --hostonly is passed, which can sometimes leave things out we actually want
#   --filesystems are needed to support mounting the squash and using the overlay
dracut \
  -L 4 \
  --force \
  --hostonly \
  --omit "${kdump_omit}" \
  --add-fstab ${fstab_kdump} \
  --compress 'xz -0 --check=crc32' \
  --kernel-cmdline "${kdump_cmdline}" \
  --add 'mdraid kdump' \
  --tmpdir "/run/initramfs/overlayfs/LiveOS/overlay-SQFSRAID-${sqfs_uuid}/var/tmp" \
  --persistent-policy by-label \
  --install 'lsblk find df' \
  --force-drivers 'raid1' \
  --filesystems 'loop overlay squashfs' \
  ${initrd_name}

echo "Unpacking generated initrd to modify some content..."
mkdir -p /tmp/ktmp

pushd /tmp/ktmp || exit 1
# Unpack the existing kdump initrd
/usr/lib/dracut/skipcpio ${initrd_name} | xzcat | cpio -id

echo "Setting ROOTDIR..."
# The overlay will be mounted here, so create it in advance
mkdir kdump/overlay/

# The default ROOTDIR results in an OOM error, so we specifically set it to the overlay where we can write to
# This also enables the dump files to be accessible on the next boot and live in /var/crash
sed -i 's/^\(ROOTDIR\)=.*$/\1=\"\/kdump\/overlay\"/' lib/kdump/save_dump.sh

# Modify the save dir also so it saves to the correct spot
sed -i 's/^\(KDUMP_SAVEDIR\)=.*$/\1=\"file:\/\/\/var\/crash\"/' etc/sysconfig/kdump
# optionally, uncomment to stay in the initrd after the dump is complete
#sed -i 's/^\(KDUMP_IMMEDIATE_REBOOT\)=.*$/\1=\"no"/' etc/sysconfig/kdump

# Use a here doc to create a simple pre-script that mounts the overlay
cat << EOF > sbin/mount_kdump_overlay.sh
mount -t overlay overlay -o rw,relatime,lowerdir=/kdump/mnt2,upperdir=/kdump/mnt0/LiveOS/overlay-SQFSRAID-${sqfs_uuid},workdir=/kdump/mnt0/LiveOS/ovlwork /kdump/overlay
EOF
chmod 755 sbin/mount_kdump_overlay.sh

# set the above script to run as a kdump prescript, which runs just before makedumpfile
sed -i 's/^\(KDUMP_REQUIRED_PROGRAMS\)=.*$/\1=\"\/sbin\/mount_kdump_overlay.sh\"/' etc/sysconfig/kdump
sed -i 's/^\(KDUMP_PRESCRIPT\)=.*$/\1=\"\/sbin\/mount_kdump_overlay.sh\"/' etc/sysconfig/kdump

# Remove the original and create the new kdump initrd with our modified script
echo "Generating modified kdump initrd..."
# Remove the existing initrd and replace it with our modified one
rm -f ${initrd_name}
find . | cpio -oac | xz -C crc32 -z -c > ${initrd_name}

popd || exit 1

check_size ${initrd_name}

# restart kdump to apply the change
echo "Restarting kdump..."
systemctl restart kdump

cleanup
