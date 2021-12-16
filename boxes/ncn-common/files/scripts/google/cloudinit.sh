#!/bin/bash

set -e

echo "Scheduling local DNS server(s) awareness updates for every 5 minutes"
echo "*/5 * * * * root . /etc/profile.d/cray.sh; /usr/bin/python3 /srv/cray/scripts/google/update-dns.py >> /var/log/cray/cron.log 2>&1" > /etc/cron.d/cray-update-dns

echo "Running initial local DNS server(s) awareness update"
while ! /usr/bin/python3 /srv/cray/scripts/google/update-dns.py; do
  sleep 5
done
systemctl restart cron
# TODO: something is wiping out the authorized_keys file, at least on Virtual Shasta, figure it out
#       traced it to something in either the update-dns.py above: restarting network services?
#       or the cron restart above?
cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
