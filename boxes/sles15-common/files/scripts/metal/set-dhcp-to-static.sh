#!/bin/bash
#
# Copyright 2014-2020 Hewlett Packard Enterprise Development LP
#

file_path='/etc/sysconfig/network/'
ethernet_list=${file_path}ethernet_interface_names.txt

# get the host_records from cloud-init
data=$(craysys metadata get host_records|jq)

# getting number of host records
number_of_entries=$(echo $data |jq .[].ip|wc -l)

# get hostname
hostname=$(cat /etc/hostname)

# removing eth0 configs
rm -rf /etc/sysconfig/network/*eth*

# create list of interfaces
ip link | awk '$0 !~ "lo|vir|wl|br|dock|veth|weave|cni|dummy|vxlan|datapath|kube|usb|ens|p1|p2|^[^0-9]" {print $2}' | sed 's/://' > "${ethernet_list}"

while IFS= read -r line
do
    # reset alias when checking cloud-init data
    alias=""

    interface=$(echo "${line}" | sed -e 's/@\(bond\|mgmt\)0//g')
    filename="ifcfg-$interface"
    if [ ! -f "$file_file_path$filename" ]; then
        # create config file
        echo "creating file ${file_path}"${filename}""
        echo -n > ${file_path}"${filename}"
        # creating mgmt0 and mgmt1 specific configs
        if [[ "$interface" =~ "cirename" ]]; then
            (
                ip l s $interface down
                rm -f /etc/sysconfig/network/*${interface}*
                for mgmt_idx in $(seq 0 3); do
                    if ip l | grep -q mgmt${mgmt_idx}; then
                        ip l s $interface name mgmt${mgmt_idx}
                        break
                    fi
                done
            ) || echo >&2 'Failed to re-resolve cirename [$interface]'
        fi
        if [[ "$interface" =~ "mgmt" ]]; then
            echo "BOOTPROTO='none'" >> ${file_path}"${filename}"
            echo "STARTMODE='auto'" >> ${file_path}"${filename}"
            continue
        fi
        # getting ip
        address="$(ip -4 addr show dev "${interface}" | awk '/inet/ {print $2}' | head -n 1)"
        subnet_mask=$(echo "$address" |cut -d '/' -f2)
        # getting alias to lookup in cloud-init
        case "$interface" in
            *vlan002)
                alias="$hostname.nmn"
            ;;
            *vlan004)
                alias="$hostname.hmn"
            ;;
            *vlan007)
                alias="$hostname.can"
            ;;
        esac

        # getting ip from cloud-init data if alias is not null
        if [ ! -z "$alias" ]; then
            for (( i=0; i<$number_of_entries; i++ )); do
                number_of_aliases=$(echo $data|jq  .[${i}].aliases[]|wc -l)
                for (( j=0; j<$number_of_aliases; j++ )); do
                    record="$(echo $data|jq -r .[${i}].aliases[${j}])"
                        if [ "$alias" == "$record" ]; then
                            address="$(echo $data|jq  -r .[${i}].ip)/$subnet_mask"
                        fi
                done
            done
        fi
        # setup configs for network interfaces that are not mgmt0/1
        case "$interface" in
            bond*)
                mtu="$(ip addr show dev "${interface}" | awk '/mtu/ {print $5}' | head -n 1)"
                mode=$(cat /sys/class/net/${interface}/bonding/mode | awk '{print $1}')
                miimon=$(cat /sys/class/net/${interface}/bonding/miimon | awk '{print $1}')
                lacp_rate=$(cat /sys/class/net/${interface}/bonding/lacp_rate | awk '{print $1}')
                xmit_hash_policy=$(cat /sys/class/net/${interface}/bonding/xmit_hash_policy | awk '{print $1}')
                mtu="$(ip addr show dev "${interface}" | awk '/mtu/ {print $5}' | head -n 1)"
                echo "BONDING_MODULE_OPTS='mode=$mode miimon=$miimon lacp_rate=$lacp_rate xmit_hash_policy=$xmit_hash_policy'" >> ${file_path}"${filename}"
                echo "BONDING_MASTER='yes'" >> ${file_path}"${filename}"
                for arg in $(cat /proc/cmdline) ; do
                    [ $interface = 'bond0' ] && slave0=mgmt0
                    if [[ $arg =~ "bond=$interface" ]]; then
                        slave0=$(echo ${arg#*$interface:} | cut -d : -f 1 | cut -d , -f1)
                        slave1=$(echo ${arg#*$interface:} | cut -d : -f 1 | cut -d , -f2)
                    fi
                done
                echo "BONDING_SLAVE0='$slave0'" >> ${file_path}"${filename}"
                echo "BONDING_SLAVE1='$slave1'" >> ${file_path}"${filename}"
            ;;
            vlan010*)
                mtu="9000"
                echo "VLAN_PROTOCOL='ieee802-1Q'" >> ${file_path}"${filename}"
                echo "ETHERDEVICE='bond1'" >> ${file_path}"${filename}"
            ;;
            vlan*)
                mtu="1500"
                echo "VLAN_PROTOCOL='ieee802-1Q'" >> ${file_path}"${filename}"
                echo "ETHERDEVICE='bond0'" >> ${file_path}"${filename}"
            ;;
            hsn*|lan*)
                # disable; allow configuration later for site-links.
                echo "BOOTPROTO='none'" >> ${file_path}"${filename}"
                echo "STARTMODE='auto'" >> ${file_path}"${filename}"
                :
            ;;
            *)
                echo "Unsupported interface: $interface"
            ;;
        esac

        # add items to the config files
        echo "IPADDR='"${address}"'" >> ${file_path}"${filename}"
        echo "BOOTPROTO='static'" >> ${file_path}"${filename}"
        echo "STARTMODE='auto'" >> ${file_path}"${filename}"
        echo "MTU='"${mtu}"'" >> ${file_path}"${filename}"
        echo "ONBOOT='yes'" >> ${file_path}"${filename}"
    else
        echo "$file_file_path$filename already exists"
    fi

done < "$ethernet_list"

# file cleanup
rm -rf $ethernet_list

# read configs
wicked ifreload all
# Ensure they let go of any old ETHERDEVs
systemctl restart wickedd-nanny && sleep 3

# Setup the route
cangw=$(craysys metadata get can-gw)
canif=$(craysys metadata get can-if)
[ -z ${canif} ] || [ -z ${canif} ] || echo "default ${cangw} - -" >/etc/sysconfig/network/ifroute-${canif}

# Clean start the network stack.
wicked ifreload all && sleep 3 && systemctl restart wicked
