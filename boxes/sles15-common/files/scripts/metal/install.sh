#!/bin/bash
set -e

. /srv/cray/scripts/metal/lib.sh

# 1. Run this first; disable bootstrap info to level the playing field for configuraiton.
breakaway() {
    # clean bootstrap/ephemeral TCP/IP information
    clean_bogies
    drop_metal_tcp_ip bond0
}


# 2. After detaching bootstrap, setup our bootloader..
bootloader() {
    local working_path=/metal/recovery
    update_auxiliary_fstab $working_path
    get_boot_artifacts $working_path
    install_grub2 $working_path
}

# 3. Metal configuration for servers and networks.
hardware() {
    setup_uefi_bootorder
    configure_lldp
    set_static_fallback
    enable_amsd
    /srv/cray/scripts/metal/set-ntp-config.sh
}

# 4. CSM Testing and dependencies
csm() {
    install_csm_rpms
}

breakaway
bootloader
hardware
