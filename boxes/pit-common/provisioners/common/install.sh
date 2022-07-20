#!/bin/bash

set -ex

# Ensure that only the desired kernel version may be installed.
# Clean up old kernels, if any. We should only ship with a single kernel.
# Lock the kernel to prevent inadvertent updates.
function kernel {
    local current_kernel

    # Grab this from csm-rpms, the running kernel may not match the kernel we installed and want until the image is rebooted.
    # This ensures we lock to what we want installed.
    current_kernel="$(grep kernel-default /srv/cray/csm-rpms/packages/node-image-non-compute-common/base.packages | awk -F '=' '{print $NF}')"

    echo "Purging old kernels ... "
    sed -i 's/^multiversion.kernels =.*/multiversion.kernels = '"${current_kernel}"'/g' /etc/zypp/zypp.conf
    zypper --non-interactive purge-kernels --details

    echo "Locking the kernel to ${current_kernel}"
    zypper addlock kernel-default && zypper locks
    
    echo "Listing currently installed kernel-default RPM:"
    rpm -qa | grep kernel-default
}
kernel

# Install generic Python tools; ensures both the default python and any other installed python system versions have 
# basic buildtools.
# NOTE: /usr/bin/python3 should point to the Python 3 version installed by python3.rpm, this is set in metal-provision.
function setup_python {
    local pythons

    local        pip_ver='21.3.1'
    local      build_ver='0.8.0'
    local setuptools_ver='59.6.0'
    local      wheel_ver='0.37.1'
    local virtualenv_ver='20.15.1'

    readarray -t pythons < <(find /usr/bin/ -regex '.*python3\.[0-9]+')
    printf 'Discovered [%s] python binaries: %s\n' "${#pythons[@]}" "${pythons[*]}"
    for python in "${pythons[@]}"; do
        $python -m pip install -U "pip==$pip_ver" || $python -m ensurepip
        $python -m pip install -U \
            "build==$build_ver" \
            "setuptools==$setuptools_ver" \
            "virtualenv==$virtualenv_ver" \
            "wheel==$wheel_ver" 
    done
}
setup_python

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
