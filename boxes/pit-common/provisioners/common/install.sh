#!/bin/bash

set -ex

# Ensure that only the desired kernel version may be installed.
# Clean up old kernels, if any. We should only ship with a single kernel.
# Lock the kernel to prevent inadvertent updates.
function kernel {
    local sles15_kernel_version
    sles15_kernel_version=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}\n" kernel-default)
    
    echo "Purging old kernels ... "
    sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${SLES15_KERNEL_VERSION}"'/g' /etc/zypp/zypp.conf
    zypper --non-interactive purge-kernels --details
    
    echo "Locking the kernel to $SLES15_KERNEL_VERSION"
    zypper addlock kernel-default
    
    echo 'Listing locks and kernel RPM(s)'
    zypper ll
    rpm -qa | grep kernel-default   
}
kernel

echo "Ensuring /srv/cray/utilities locations are available for use system-wide"
ln -s /srv/cray/utilities/common/craysys/craysys /bin/craysys
echo "export PYTHONPATH=\"/srv/cray/utilities/common\"" >> /etc/profile.d/cray.sh

echo "Enabling/disabling services"
systemctl disable mdcheck_continue.service
systemctl disable mdcheck_start.service
systemctl disable mdmonitor-oneshot.service
systemctl disable mdmonitor.service
systemctl disable postfix.service && systemctl stop postfix.service
systemctl enable apache2.service
systemctl enable basecamp.service
systemctl enable ca-certificates.service
systemctl enable chronyd.service
systemctl enable dnsmasq.service
systemctl enable getty@tty1.service
systemctl enable issue-generator.service
systemctl enable kdump-early.service
systemctl enable kdump.service
systemctl enable lldpad.service
systemctl enable multi-user.target
systemctl enable nexus.service
systemctl enable purge-kernels.service
systemctl enable rc-local.service
systemctl enable rollback.service
systemctl enable serial-getty@ttyS0.service
systemctl enable sshd.service
systemctl enable wicked.service
systemctl enable wickedd-auto4.service
systemctl enable wickedd-dhcp4.service
systemctl enable wickedd-dhcp6.service
systemctl enable wickedd-nanny.service
systemctl set-default multi-user.target

#======================================
# Add custom aliases and environment
# variables
#--------------------------------------
cat << EOF >> /root/.bashrc
alias ip='ip -c'
alias ll='ls -l --color'
alias lid='for file in \$(ls -1d /sys/bus/pci/drivers/*/0000\:*/net/*); do printf "% -6s %s\n" "\$(basename \$file)" \$(grep PCI_ID "\$(dirname \$(dirname \$file))/uevent" | cut -f 2 -d '='); done'
alias wipeoff="for script in /var/www/ncn-*/script.ipxe; do sed -i 's/metal.no-wipe=0/metal.no-wipe=1/g' \\\$script; done; wipestat"
alias wipeon="for script in /var/www/ncn-*/script.ipxe; do sed -i 's/metal.no-wipe=1/metal.no-wipe=0/g' \\\$script; done; wipestat"
alias wipestat='grep -o metal.no-wipe=[01] /var/www/ncn-*/script.ipxe'
source <(kubectl completion bash) 2>/dev/null
EOF
