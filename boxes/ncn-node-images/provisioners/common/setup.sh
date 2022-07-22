#!/usr/bin/env bash

set -exu
# Switch to / directory
cd /

# Find device and partition of /
df . | tail -n 1 | tr -s " " | cut -d " " -f 1 | sed -E -e 's/^([^0-9]+)([0-9]+)$/\1 \2/' |
if read DEV_DISK DEV_PARTITION_NR && [ -n "$DEV_PARTITION_NR" ]; then
    echo "Expanding $DEV_DISK partition $DEV_PARTITION_NR";
    sgdisk --move-second-header
    sgdisk --delete=${DEV_PARTITION_NR} "$DEV_DISK"
    sgdisk --new=${DEV_PARTITION_NR}:0:0 --typecode=0:8e00 ${DEV_DISK}
    partprobe "$DEV_DISK"
    
    # Handle ext2/3/4 or xfs.
    if ! resize2fs "$DEV_DISK"; then
        if ! xfs_growfs ${DEV_DISK}${DEV_PARTITION_NR}; then
            echo >&2 "Neither resize2fs nor xfs_growfs could resize the device. Potential filesystem mismatch on [$DEV_DISK]."
            lsblk "$DEV_DISK"
        fi
    fi
fi

echo "Initializing directories and resources"
mkdir -pv /srv/cray
cp -prv /tmp/files/* /srv/cray/ && rm -rf /tmp/files
find /srv/cray/scripts -type f -name *.sh -exec chmod +x {} \+
