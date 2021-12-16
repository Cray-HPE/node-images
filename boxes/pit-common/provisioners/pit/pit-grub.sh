#!/bin/bash

sed -e '/^\s*GRUB_CMDLINE_LINUX_DEFAULT=/s/="[^"]*"/="payload=file://dev/sda3 splash=silent mediacheck=0 biosdevname=1 console=tty0 console=ttyS0,115200 mitigations=auto iommu=pt pcie_ports=native transparent_hugepage=never rd.shell rd.md=0 rd.md.conf=0"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

#!/bin/bash

sed -e '/^\s*GRUB_CMDLINE_LINUX_DEFAULT=/s/="[^"]*"/="mitigations=auto biosdevname transparent_hugepage=never crashkernel=256M console=ttyS0,38400n8d"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg