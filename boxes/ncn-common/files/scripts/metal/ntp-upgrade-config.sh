#!/bin/bash
# Copyright 2020 HPED LP
set -e

usage() {
  # Generates a usage line
  # Any line startng with with a #/ will show up in the usage line
  grep '^#/' "$0" | cut -c4-
}

# Show usage when --help is passed
expr "$*" : ".*--help" > /dev/null && usage && exit 0

# if the host this is running on is m001
if [[ "$HOSTNAME" == "ncn-m001" ]]; then
  # we're handed off, so query bss
  UPSTREAM_NTP_SERVER=$(craysys metadata get upstream_ntp_server || echo -n '' )
else
  # all other nodes should still use m001 as their upstream
  UPSTREAM_NTP_SERVER="ncn-m001"
fi
NTP_PEERS=$(craysys metadata get ntp_peers || echo -n '' )
NTP_LOCAL_NETS=$(craysys metadata get ntp_local_nets || echo -n '' )
CHRONY_CONF=/etc/chrony.d/cray.conf


edit_default_config() {
  # disable the default pool.ntp.org since the NCNs can't reach the outside Internet
  sed -i 's/^\!/#/' /etc/chrony.conf
}

create_chrony_config() {
  # clear the file first, making it if needed
  true >"$CHRONY_CONF"

  if [[ -z $UPSTREAM_NTP_SERVER ]]; then
    :
  else
    echo "server $UPSTREAM_NTP_SERVER iburst trust" >>"$CHRONY_CONF"
  fi

  for net in ${NTP_LOCAL_NETS}
  do
     echo "allow $net" >>"$CHRONY_CONF"
  done

  # Step the clock in a stricter manner than the default *this is the value used in 1.3
  echo "makestep 0.1 3" >>"$CHRONY_CONF"
  echo "local stratum 3 orphan" >>"$CHRONY_CONF"
  echo "log measurements statistics tracking" >>"$CHRONY_CONF"
  echo "logchange 1.0" >>"$CHRONY_CONF"

  for n in $NTP_PEERS
  do
    if [[ "$HOSTNAME" != "$n" ]] || [[ "$n" != "ncn-m001" ]]; then
      echo "peer $n minpoll -2 maxpoll 9 iburst" >>"$CHRONY_CONF"
    fi
  done
}

#/ Usage: set-ntp-config.sh [--help]
#/                          [-u|--upstream-site-ntp] HOST_OR_IP
#/
#/    Configures NTP on the NCNs
#/

UNKNOWN=()
while [[ $# -gt 0 ]]
do
  case "$1" in
    -u|--upstream-site-ntp)
      UPSTREAM_NTP_SERVER="$2"
      shift
      shift
      ;;
    *) # unknown option
      UNKNOWN+=("$1")
      shift
      ;;
  esac
done

set -- "${UNKNOWN[@]}" # restore positional parameters

edit_default_config
create_chrony_config
# Apply the new configs
systemctl restart chronyd
# Show the current time
echo "CURRENT TIME SETTINGS"
echo "rtc: $(hwclock)"
echo "sys: $(date "+%Y-%m-%d %H:%M:%S.%6N%z")"
# Ensure we use UTC
timedatectl set-timezone UTC
# bursting immediately after restarting the service can sometimes give a 503, even if the server is reachable.
# This just gives the service a little bit of time to settle
sleep 15
# quickly make (4 good measurements / 4 maximum)
chronyc burst 4/4
# wait a short bit to make sure the measurements happened
sleep 15
# then step the clock immediately if neeed
chronyc makestep
hwclock --systohc --utc
systemctl restart chronyd

echo "NEW TIME SETTINGS"
echo "rtc: $(hwclock)"
echo "sys: $(date "+%Y-%m-%d %H:%M:%S.%6N%z")"
