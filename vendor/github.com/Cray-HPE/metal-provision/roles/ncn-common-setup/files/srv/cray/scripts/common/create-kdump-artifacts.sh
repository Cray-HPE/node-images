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
set -euo pipefail

# Source common dracut parameters.
. "$(dirname $0)/dracut-lib.sh"

# show the line that we failed and on and exit non-zero

trap 'catch $? $LINENO; cleanup; exit 1' ERR

# if the script is interrupted, run the cleanup function
trap 'cleanup' INT EXIT

# catch() prints what line the script failed on, runs the cleanup function, and then exits non-zero
catch() {
    # Show what line the error occurred on because it can be difficult to detect in a dracut environment
    echo "CATCH: exit code $1 occurred on line $2 in $(basename "${0}")"
    cleanup
    exit 1
}


# cleanup() removes temporary files, puts things back where they belong, etc.
cleanup() {
    echo "CLEANUP: cleanup function running ..."

    # Restore the dracut config if it was removed.
    if [ -f /run/rootfsbase/etc/dracut.conf.d/05-metal.conf ]; then
        cp -v /run/rootfsbase/etc/dracut.conf.d/05-metal.conf /etc/dracut.conf.d/05-metal.conf
    fi
}


# check_size() offers a CAUTION message if the initrd is larger then 20MB
# this is just a soft warning since several factors can influence running out of memory including:
# crashkernel= parameters, drivers that are loaded, modules that are loaded, etc.
# so it's more of a your mileage may vary message
check_size() {

    local initrd="$1"
    local max=20000000 # kdump initrds larger than 20M may run into issues with memory

    if [[ "$(stat --format=%s $initrd)" -ge "$max" ]]; then
        echo >&2 "CAUTION: initrd might be too large ($(stat --format=%s $initrd)) and may exceed available memory (OOM) if used"
    else
        echo "initrd size is $(stat --format=%s $initrd) bytes"
    fi
}

function build_initrd {

    local initrd_name
    local kdump_add
    local kdump_omit
    local kdump_omit_drivers

    sed -i -E 's/(KDUMP_COMMANDLINE_APPEND=)"(.*)"/\1"rd.info \2"/p' /etc/sysconfig/kdump
    initrd_name="/boot/initrd-${KVER}-kdump"

    # kdump-specific modules to add
    kdump_add=${ADD[*]}
    kdump_add+=( 'kdump' )

    # modules to remove
    kdump_omit=${OMIT[*]}
    kdump_omit+=( "plymouth" )
    kdump_omit+=( "resume" )
    kdump_omit+=( "usrmount" )

    # Omit these drivers to make a smaller initrd.
    kdump_omit_drivers=$OMIT_DRIVERS
    kdump_omit_drivers+=( "mlx5_core" )
    kdump_omit_drivers+=( "mlx5_ib" )
    kdump_omit_drivers+=( "sunrpc" )
    kdump_omit_drivers+=( "xhci_hcd" )

    # move the 05-metal.conf file out of the way while the initrd is generated
    # it causes some conflicts if it's in place when 'dracut' is called.
    # This is restored by the cleanup function at the end.
    if [ -f /run/rootfsbase/etc/dracut.conf.d/05-metal.conf ]; then
        rm -f /etc/dracut.conf.d/05-metal.conf
    else
        echo 'Not removing metal dracut config because no backup exists; this is likely running in the NCN pipeline and the inclusion of this file is safe.'
    fi

    # generate the kdump initrd
    # Special notes for specific parameters:
    # - hostonly makes a smaller initrd for the system; if this script is ran in the pipeline this should be swapped for --no-hostonly.
    # - fstab is used to mitigate risk from reading /proc/mounts
    # - mount these are given to support mounting both /kdump/boot and /kdump/mnt0, /kdump/boot is meaningless so this is done as a formality
    # - filesystems only xfs is needed
    # - no-hostonly-default-device removes auto-resolution of root, this neatens the dracut output
    # - nohardlink is needed to provide init properly, hardlinking does not work since init exists on a different filesystem
    # - force-drivers raid1 is necessary to be able to view the raids we have
    echo "Creating initrd/kernel artifacts ..."
    dracut \
        -L 4 \
        --force \
        --hostonly \
        --omit "$(printf '%s' "${kdump_omit[*]}")" \
        --omit-drivers "$(printf '%s' "${kdump_omit_drivers[*]}")" \
        --add "$(printf '%s' "${kdump_add[*]}")" \
        --fstab \
        --nohardlink \
        --filesystems 'xfs' \
        --compress 'xz -0 --check=crc32' \
        --no-hostonly-default-device \
        --persistent-policy by-label \
        --printsize \
        --print-cmdline \
        --kver ${KVER} \
        --force-drivers 'raid1' \
        ${initrd_name}

    check_size ${initrd_name}

    # restart kdump to apply the change
    echo "Restarting kdump ..."
    systemctl restart kdump
    echo "Done!"
}

build_initrd
