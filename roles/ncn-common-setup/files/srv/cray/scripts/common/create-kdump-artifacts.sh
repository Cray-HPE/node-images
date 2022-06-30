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
# create-kdump-artifacts.sh creates an initrd for use with kdump
#   this specialized initrd is booted when a node crashes
#   it is specifically designed to work with the persistent overlay and RAIDs in use in Shasta 1.4+
set -ex

# Source common dracut parameters.
. "$(dirname $0)/dracut-lib.sh"

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

initrd_name="/boot/initrd-$KVER-kdump"

echo "Creating initrd/kernel artifacts..."

# kdump-specific modules to add
kdump_add=$ADD
kdump_add+=( 'kdump' )

# kdump-specific kernel parameters
init_cmdline=$(cat /proc/cmdline)
kdump_cmdline=()
for cmd in $init_cmdline; do
    # grab only the raid, live, and root directives so we can use them in kdump
    if [[ $cmd =~ ^rd\.md.* ]] || [[ $cmd =~ ^rd\.live.* ]] || [[ $cmd =~ ^root.* ]] ; then
      cmd=$(basename "$(echo $cmd  | awk '{print $1}')")
      kdump_cmdline+=( "$cmd" )
    fi
done
kdump_cmdline+=( "irqpoll" )
kdump_cmdline+=( "nr_cpus=1" )
kdump_cmdline+=( "selinux=0" )
kdump_cmdline+=( "reset_devices" )
kdump_cmdline+=( "cgroup_disable=memory" )
kdump_cmdline+=( "mce=off" )
kdump_cmdline+=( "numa=off" )
kdump_cmdline+=( "udev.children-max=2" )
kdump_cmdline+=( "acpi_no_memhotplug" )
kdump_cmdline+=( "rd.neednet=0" )
kdump_cmdline+=( "rd.shell" )
kdump_cmdline+=( "panic=10" )
kdump_cmdline+=( "nohpet" )
kdump_cmdline+=( "nokaslr" )
kdump_cmdline+=( "transparent_hugepage=never" )
# mellanox drivers need to be blacklisted in order to prevent OOM errors
kdump_cmdline+=( "rd.driver.blacklist=mlx5_core,mlx5_ib" )
kdump_cmdline+=( "rd.info" )
# adjust here if you want a break point
#kdump_cmdline+=( "rd.break=pre-mount" )
# uncomment to see debug info when running in the kdump initrd
#kdump_cmdline+=( "rd.debug=1" )

# modules to remove
kdump_omit=()
kdump_omit+=( "plymouth" )
kdump_omit+=( "resume" )
kdump_omit+=( "usrmount" )
kdump_omit+=( "haveged" )
kdump_omit+=( "metaldmk8s" )
kdump_omit+=( "metalluksetcd" )
kdump_omit+=( "metalmdsquash" )

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
  --omit "$(printf '%s' "${kdump_omit[*]}")" \
  --omit-drivers "$(printf '%s' "${OMIT_DRIVERS[*]}")" \
  --add "$(printf '%s' "${kdump_add[*]}")" \
  --install 'lsblk find df' \
  --add-fstab ${fstab_kdump} \
  --compress 'xz -0 --check=crc32' \
  --kernel-cmdline "$(printf '%s' "${kdump_cmdline[*]}")" \
  --tmpdir "/run/initramfs/overlayfs/LiveOS/overlay-SQFSRAID-${sqfs_uuid}/var/tmp" \
  --persistent-policy by-label \
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

# this is a hacky workaround to remove a rogue fstab entry in 1.2+
# /kdump/mnt0 should be the ROOTRAID, not SQFSRAID
# it is added by the kdump dracut module, but can be inaccurate if the root label matches the squashfs label
# prior to this commit, earlier versions of csm will hit this issue,
# so this can help provide backwards compatibility if kdump needs to be enabled on those environments
sed -i '/^LABEL=SQFSRAID \/kdump\/mnt0/d' etc/fstab

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
