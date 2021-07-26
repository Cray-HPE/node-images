#!/usr/bin/env bash

echo Running $0

## Set persistent network boot.
#
function set_ncn_bootorder() {
  # If "Boot Parameter 5 failed: Insufficient privilege level" is thrown, at least one-shot set nextboot to PXE to emulate order.
  # Insufficient privilege level is thrown on incompatible BMC configuration or firmware.
  ipmitool chassis bootdev pxe options=efiboot,persistent ||
    ipmitool chassis bootdev pxe options=efiboot ||
    echo 'Failed to set official bootorder!'
}
set_ncn_bootorder

#
## Set static IP; assign the current IP as static.
#
function set_static_fallback() {
  export netconf=/tmp/netconf
  # BMCs either run dedicated on lan3 (last LAN channel as is the case with Intel's),
  # or lan1 (when there's only one channel).
  if ipmi_output_3=$(ipmitool lan print 3 2>/dev/null)
  then
    export lan=3
    echo "$ipmi_output_3" > $netconf
  fi

  if [ -z $lan ] && ipmi_output_1=$(ipmitool lan print 1 2>/dev/null)
  then
    export lan=1
    echo "$ipmi_output_1" > $netconf
  fi

  if [ -z $lan ]
  then
    echo "Failed to determine which LAN channel to use!"
  fi

  local ipaddr=$(grep -Ei 'IP Address\s+\:' $netconf | awk '{print $NF}')
  local netmask=$(grep -Ei 'Subnet Mask\s+\:' $netconf | awk '{print $NF}')
  local defgw=$(grep -Ei 'Default Gateway IP\s+\:' $netconf | awk '{print $NF}')
  ipmitool lan set $lan ipsrc static || :
  ipmitool lan set $lan ipaddr $ipaddr || :
  ipmitool lan set $lan netmask $netmask || :
  ipmitool lan set $lan defgw ipaddr $defgw || :
  ipmitool lan print $lan || :
  rm -f $netconf
}
set_static_fallback

function enable_amsd() {
    if ! rpm -qi amsd >/dev/null 2>&1 ; then
        echo 'amsd is not installed, ignoring amsd services'
        return 0
    fi
    echo scanning vendor ... && vendor=$(ipmitool fru | grep -i 'board mfg' | tail -n 1 | cut -d ':' -f2 | tr -d ' ')
    case $vendor in
        *Marvell*|HP|HPE)
            echo Enabling iLO services for detected vendor: $vendor
            systemctl enable ahslog
            systemctl enable amsd
            systemctl enable smad

            # Not needed; SCSI, IDE, nor FCA are used
            # systemctl enable cpqFca
            # systemctl enable cpqIde
            # systemctl enable cpqScsi

            systemctl start ahslog
            systemctl start amsd
            systemctl start smad

            # Not needed; SCSI, IDE, nor FCA are used
            # systemctl start cpqFca
            # systemctl start cpqIde
            # systemctl start cpqScsi
            ;;
        *)
        echo >&2 not enabling iLO services for detected vendor: $vendor
        ;;
    esac
}
enable_amsd

echo 'Setting cpugovernor' && cpupower frequency-set --governor performance
