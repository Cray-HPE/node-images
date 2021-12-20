#!/bin/bash
# Author: Russell Bunch <doomslayer@hpe.com>
trap "printf >&2 'Metal Install: [ % -20s ]' 'failed'" ERR TERM HUP INT
trap "echo 'See logfile at: /var/log/cloud-init-metal.log'" EXIT
BMC_RESET=${BMC_RESET:-'cold'}
set -e

# Load the metal library.
printf 'Metal Install: [ % -20s ]\n' 'loading ...' && . /srv/cray/scripts/metal/metal-lib.sh && printf 'Metal Install: [ % -20s ]\n' 'loading done' && sleep 2

# 1. Run this first; disable bootstrap info to level the playing field for configuration.
breakaway() {
    # clean bootstrap/ephemeral TCP/IP information
    (
        set -x
        write_default_route
        clean_bogies
        drop_metal_tcp_ip bond0
    ) 2>/var/log/cloud-init-metal-breakaway.error
}

# 2. After detaching bootstrap, setup our bootloader..
bootloader() {
    (
        set -x
        local working_path=/metal/recovery
        update_auxiliary_fstab $working_path
        get_boot_artifacts $working_path
        install_grub2 $working_path
    ) 2>/var/log/cloud-init-metal-bootloader.error
}

# 3. Metal configuration for servers and networks.
hardware() {
    (
        set -x
        setup_uefi_bootorder
        configure_lldp
        set_static_fallback
        enable_amsd
    ) 2>/var/log/cloud-init-metal-hardware.error
}

# 4. BMC Reset for shaking off any preconditions.
bmc_reset() {
    cat >&2 << EOM
NOTICE: The BMC is being RESET in order to cease and desist any further DHCPREQUESTs from the BMC.
The remote management module controllers (a.k.a. RMMC and BMCs) have been known to continue 
DHCPREQUESTs despite changing their IP source to STATIC.

CONSOLES will cease working while the BMC is reset (8-20seconds).
EOM
    (
        set -x
        # One could `export BMC_RESET='warm'` to change the behavior here.
        reset_bmc $BMC_RESET
    ) 2>/var/log/cloud-init-metal-bmc_reset.error
    printf 'Metal Install: [ % -20s ]\n' 'waiting: ipmitool' >&2 && sleep 5
    while ipmitool >/dev/null 2>&1; do sleep 1; done
    echo >&2 -e '\nBMC is now responding; conman consoles will reconnect imminently.' | tee -a /var/log/cloud-init-metal-bmc_reset.error
    printf 'Metal Install: [ % -20s ]\n' 'waiting: consoles' >&2 && sleep 10
}


# 5. CSM Testing and dependencies
csm() {
    (
        set -x
        install_csm_rpms
    ) 2>/var/log/cloud-init-metal-csm.error
}

# MAIN
(
    # 1.
    printf 'Metal Install: [ % -20s ]\n' 'running: breakaway' >&2
    [ -n "$METAL_TIME" ] && time breakaway || breakaway

    # 2.
    printf 'Metal Install: [ % -20s ]\n' 'running: fallback' >&2
    [ -n "$METAL_TIME" ] && time bootloader || bootloader

    # 3.
    printf 'Metal Install: [ % -20s ]\n' 'running: hardware' >&2
    [ -n "$METAL_TIME" ] && time hardware || hardware

    # 4.
    printf 'Metal Install: [ % -20s ]\n' "running: BMC Reset" >&2
    [ -n "$METAL_TIME" ] && time bmc_reset || bmc_reset
    
    # 5. 
    printf 'Metal Install: [ % -20s ]\n' 'running: CSM layer' >&2
    [ -n "$METAL_TIME" ] && time csm || csm

) >/var/log/cloud-init-metal.log

printf 'Metal Install: [ % -20s ]\n' 'done and complete'
