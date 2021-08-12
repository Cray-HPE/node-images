#!/bin/bash

set -e

umount /mnt/squashfs
rm -rf /mnt/squashfs
rm -rf /squashfs
rm /tmp/kis.tar.gz || true
