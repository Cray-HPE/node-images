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
    # Restore the dracut config if it was removed.
    cp -v /run/rootfsbase/etc/dracut.conf.d/05-metal.conf /etc/dracut.conf.d/05-metal.conf

    # Ensures things are unmounted via 'trap' even if the command fails
    echo "CLEANUP: cleanup function running..."
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
    echo "initrd size is $(stat --format=%s $initrd) bytes"
  fi
}

initrd_name="/boot/initrd-$KVER-kdump"

echo "Creating initrd/kernel artifacts..."
# kdump-specific modules to add
kdump_add=${ADD[@]}
kdump_add+=( 'kdump' )
# kdump-specific kernel parameters
init_cmdline=$(cat /proc/cmdline)
kdump_cmdline=()
for cmd in $init_cmdline; do
    # cleans up first argument when running this script on a disk-booted system
    if [[ $cmd =~ kernel$ ]]; then
        cmd=$(basename "$(echo $cmd  | awk '{print $1}')")
    fi
    if [[ $cmd =~ ^rd.live.overlay.reset ]] ; then :
    elif [[ ! $cmd =~ ^metal. ]] && [[ ! $cmd =~ ^ip=.*:dhcp ]] && [[ ! $cmd =~ ^bootdev= ]] || [[ ! $cmd =~ ^root ]]; then
        kdump_cmdline+=( "${cmd//;/\\;}" )
    fi
done

# kdump-specific kernel parameters
kdump_cmdline+=( "root=LABEL=BOOTRAID" )
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

# modules to remove
kdump_omit=${OMIT[@]}
kdump_omit+=( "plymouth" )
kdump_omit+=( "resume" )
kdump_omit+=( "metalmdsquash" )
kdump_omit+=( "metaldmk8s" )
kdump_omit+=( "metalluksetcd" )
kdump_omit+=( "usrmount" )

# Omit these drivers to make a smaller initrd.
kdump_omit_drivers=$OMIT_DRIVERS
kdump_omit_drivers+=( "mlx5_core" )
kdump_omit_drivers+=( "mlx5_ib" )
kdump_omit_drivers+=( "sunrpc" )
kdump_omit_drivers+=( "xfs" )
kdump_omit_drivers+=( "xhci_hcd" )

# move the 05-metal.conf file out of the way while the initrd is generated
# it causes some conflicts if it's in place when 'dracut' is called
rm -f /etc/dracut.conf.d/05-metal.conf

# generate the kdump initrd
dracut \
  -L 4 \
  --force \
  --hostonly \
  --omit "$(printf '%s' "${kdump_omit[*]}")" \
  --omit-drivers "$(printf '%s' "${kdump_omit_drivers[*]}")" \
  --add "$(printf '%s' "${kdump_add[*]}")" \
  --install 'lsblk find df' \
  --mount "LABEL=BOOTRAID /root/ vfat" \
  --compress 'xz -0 --check=crc32' \
  --kernel-cmdline "$(printf '%s' "${kdump_cmdline[*]}")" \
  --persistent-policy by-label \
  --mdadmconf \
  --printsize \
  --force-drivers 'raid1 vfat' \
  --filesystems 'ext4 vfat' \
  ${initrd_name}

check_size ${initrd_name}

# restart kdump to apply the change
echo "Restarting kdump..."
systemctl restart kdump

cleanup
