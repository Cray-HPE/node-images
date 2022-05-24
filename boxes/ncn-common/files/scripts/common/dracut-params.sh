#!/bin/bash


export OMIT=( "btrfs" "cifs" "dmraid" "dmsquash-live-ntfs" "fcoe" "fcoe-uefi" "iscsi" "modsign" "multipath" "nbd" "nfs" "ntfs-3g" )
export OMIT_DRIVERS=( "ecb" "hmac" "md5" )
export ADD=( "mdraid" )
export FORCE_ADD=( "dmsquash-live" "livenet" "mdraid" )
export INSTALL=( "less" "rmdir" "sgdisk" "vgremove" "wipefs" )

