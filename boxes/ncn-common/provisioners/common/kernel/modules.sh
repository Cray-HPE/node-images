#!/bin/bash

DISABLED_MODULES="libiscsi"
MODPROBE_FILE=/etc/modprobe.d/disabled-modules.conf

touch $MODPROBE_FILE

for mod in $DISABLED_MODULES; do
    echo "install $mod /bin/true" >> $MODPROBE_FILE
done
