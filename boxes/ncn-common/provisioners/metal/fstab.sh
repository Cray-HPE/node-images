#!/bin/sh

metal_conf=/etc/dracut.conf.d/05-metal.conf
metal_fstab=/etc/fstab.metal

[ ! -f $metal_conf ] && touch $metal_conf

if grep -q "$metal_fstab" "$metal_conf" ; then :
else
    printf 'add_fstab+=%s\n' "$metal_fstab" >$metal_conf
fi
