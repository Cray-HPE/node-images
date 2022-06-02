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

  resize2fs ${DEV_DISK}${DEV_PARTITION_NR}
fi

echo "Initializing directories and resources"
mkdir -p /srv/cray
cp -r /tmp/files/* /srv/cray/
chmod +x -R /srv/cray/scripts
rm -rf /tmp/files
