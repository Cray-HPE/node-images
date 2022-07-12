#!/bin/bash

sed -e '/^\s*GRUB_CMDLINE_LINUX_DEFAULT=/s/="[^"]*"/="mitigations=auto biosdevname transparent_hugepage=never crashkernel=256M console=ttyS0,38400n8d"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
