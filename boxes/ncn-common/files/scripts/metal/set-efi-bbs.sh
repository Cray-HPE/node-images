#!/bin/bash
# Author: Russell Bunch <doomslayer@hpe.com>
# Usage: This will dangerously set the boot order to the required order for IMAGE BOOTING
# Warning: This should not be used on a system using a conventional wizard-based installer; this prefers netboot first, always.

# Set to 1 to skip enforcing the order, but still cleanup the boot menu.
# This will let the order fall into however the BIOS wants it; grouping netboot, disk, and removable options.
export no_enforce=0
export efibootmgr_prefix=''
cat << EOM
${0:-$(whoami)} is enforcing boot order ...
these use the same commands from the manual page ...
    GitHub docs: https://github.com/Cray-HPE/docs-csm/blob/main/101-NCN-BOOTING.md#setting-order
EOM

(
function fail_host {
    echo >&2 no prefix-driver for hostname: $hostname
    exit 1
}


function trim {
    echo disabling undesired boot entries $(cat /tmp/rbbs*) && cat /tmp/rbbs* | sort | sed 's/^Boot//g' | awk '{print $1}' | tr -d '*' | xargs -i efibootmgr -b {} -A
}


function remove {
    echo removing undesired boot entries $(cat /tmp/sbbs*) && cat /tmp/sbbs* | sort | sed 's/^Boot//g' | awk '{print $1}' | tr -d '*' | xargs -i efibootmgr -b {} -B
}

function enforce {
    echo enforcing boot order $(cat /tmp/bbs*) && efibootmgr -o $efibootmgr_prefix$(cat /tmp/bbs* | sed 's/^Boot//g' | awk '{print $1} ' | tr -d '*' | tr -d '\n' | sed -r 's/(.{4})/\1,/g;s/,$//'),$(cat /tmp/rbbs* | sed 's/^Boot//g' | awk '{print $1} ' | tr -d '*' | tr -d '\n' | sed -r 's/(.{4})/\1,/g;s/,$//') | grep -i bootorder
    echo activating boot entries && cat /tmp/bbs* | awk '!x[$0]++' | sed 's/^Boot//g' | tr -d '*' | awk '{print $1}' | xargs -r -i efibootmgr -b {} -a
}

# uses /tmp/rbbs99
function specials {
    # TODO: If Marvell; then ensure PXE retries only once per NIC.
    echo 'removing Shasta V1.3 items' && efibootmgr | grep -iP '(crayinstall|sles-secureboot)' | tee /tmp/sbbs
}

echo scanning vendor ... && vendor=$(ipmitool fru | grep -i 'board mfg' | tail -n 1 | cut -d ':' -f2 | tr -d ' ')
hostname=${hostname:-$(hostname)}
set -e
# Add vendors here; add like-vendors on the same case statement.
# "like-vendors" means their efibootmgr outboot matches

# formatting:
# if another vendor is identical then it should live with another.
# vendors may have differing hostnames, depending where this script runs
# vendor)
#   hostname_prefix_1)
#     file1)
#     fileN)
#   hostname_prefix_2)
#     file1)
#     fileN)
#   hostname_prefix_N)
#     file1)
#     fileN)
#   error)
#   remove_file_1
#   remove_file_N
# done
case $vendor in
    *GIGABYTE*)
        # Removal file(s) ...
        efibootmgr | grep -ivP '(pxe ipv?4.*)' | grep -iP '(adapter|connection|nvme|sata)' | tee /tmp/rbbs1
        efibootmgr | grep -iP '(pxe ipv?4.*)' | grep -i connection | tee /tmp/rbbs2
        efibootmgr | grep 'EFI Shell' | tee /tmp/rbbs3
	efibootmgr_prefix=''
        trim
        specials
        remove
        case $hostname in
            ncn-m*)
                efibootmgr | grep -iP '(pxe ipv?(4|6).*adapter)' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                efibootmgr | grep 'UEFI OS' | tee /tmp/bbs3
                ;;
            ncn-s*)
                efibootmgr | grep -iP '(pxe ipv?(4|6).*adapter)' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                efibootmgr | grep 'UEFI OS' | tee /tmp/bbs3
                ;;
            ncn-w*)
                efibootmgr | grep -iP '(pxe ipv?(4|6).*adapter)' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                efibootmgr | grep 'UEFI OS' | tee /tmp/bbs3
                ;;
            *)
                fail_host
                ;;
        esac
        ;;
    *Marvell*|HP|HPE)
        # Removal file(s) ...
        efibootmgr | grep -vi 'pxe ipv4' | grep -i adapter |tee /tmp/rbbs1
        efibootmgr | grep -iP '(sata|nvme)' | tee /tmp/rbbs2
	    efibootmgr_prefix='0000,'
        trim
        specials
        remove
        case $hostname in
            ncn-m*)
                efibootmgr | grep -i 'port 1' | grep -i 'pxe ipv4' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                ;;
            ncn-s*)
                efibootmgr | grep -i 'port 1' | grep -i 'pxe ipv4' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                ;;
            ncn-w*)
                efibootmgr | grep -i 'port 1' | grep -i 'pxe ipv4' | tee /tmp/bbs1
                efibootmgr | grep cray | tee /tmp/bbs2
                ;;
            *)
                fail_host
                ;;
        esac
        ;;
    *'Intel'*'Corporation'*)
        # Removal file(s) ...
        efibootmgr | grep -vi 'ipv4' | grep -iP '(sata|nvme|uefi)' | tee /tmp/rbbs1
        efibootmgr | grep -i baseboard | tee /tmp/rbbs2
     	efibootmgr_prefix=''
        trim
        specials
        remove
        case $hostname in
            ncn-m*)
                efibootmgr | grep -i 'ipv4' | grep -iv 'baseboard' | tee /tmp/bbs1
                efibootmgr | grep -i 'cray' | tee /tmp/bbs2
                ;;
            ncn-s*)
                efibootmgr | grep -i 'ipv4' | grep -iv 'baseboard' | tee /tmp/bbs1
                efibootmgr | grep -i 'cray' | tee /tmp/bbs2
                ;;
            ncn-w*)
                efibootmgr | grep -i 'ipv4' | grep -iv 'baseboard' | tee /tmp/bbs1
                efibootmgr | grep -i 'cray' | tee /tmp/bbs2
                ;;
            *)
                echo >&2 $0 Unsupported node name $hostname
                exit 1
                ;;
        esac
        ;;
    *)
        echo >&2 not modifying unknown vendor: $vendor
        exit 1
        ;;
esac

[ "$no_enforce" = 0 ] && enforce

)>/var/log/metal-efi-bbs.log && echo Finished setting boot order

echo log file located at /var/log/metal-efi-bbs.log
