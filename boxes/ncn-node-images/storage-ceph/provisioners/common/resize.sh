#!/bin/bash

set -x

lsblk

printf "Fix\n" | parted ---pretend-input-tty /dev/vda print
printf "Yes\n100%%\n" | parted ---pretend-input-tty /dev/vda resizepart 2
resize2fs /dev/vda2