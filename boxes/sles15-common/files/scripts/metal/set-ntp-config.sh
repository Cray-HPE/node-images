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

#/ Usage: set-ntp-config.sh [--help]
#/
#/    Immediately steps the clocks and syncs with NTP
#/

# Apply the new configs
systemctl restart chronyd

# Show the current time
echo "CURRENT TIME SETTINGS"
echo "rtc: $(hwclock)"
echo "sys: $(date "+%Y-%m-%d %H:%M:%S.%6N%z")"
# bursting immediately after restarting the service can sometimes give a 503, even if the server is reachable.
# This just gives the service a little bit of time to settle
sleep 15
# quickly make (4 good measurements / 4 maximum)
chronyc burst 4/4
# wait a short bit to make sure the measurements happened
sleep 15
# then step the clock immediately if neeed
chronyc makestep

systemctl restart chronyd

echo "NEW TIME SETTINGS"
echo "rtc: $(hwclock)"
echo "sys: $(date "+%Y-%m-%d %H:%M:%S.%6N%z")"
