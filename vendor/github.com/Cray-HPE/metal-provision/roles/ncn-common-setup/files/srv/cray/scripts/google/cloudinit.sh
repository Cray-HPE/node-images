#!/bin/bash

set -e

echo "Wait for google guest agent to get started"
until systemctl is-active google-guest-agent.service >> /dev/null;
do 
  sleep 1
done
echo "Give google guest agent 10 seconds to get fully initialized"
sleep 10

echo "Setting up root SSH keys from 'cloud-init' (aka platform metadata)"
craysys metadata get root-private-key > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
craysys metadata get root-public-key > /root/.ssh/id_rsa.pub
chmod 644 /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 644 /root/.ssh/authorized_keys

echo "Scheduling local DNS server(s) awareness updates for every 5 minutes"
echo "*/5 * * * * root . /etc/profile.d/cray.sh; /etc/ansible/gcp/bin/python3 /srv/cray/scripts/google/update-dns.py >> /var/log/cray/cron.log 2>&1" > /etc/cron.d/cray-update-dns

echo "Running initial local DNS server(s) awareness update"
while ! /etc/ansible/gcp/bin/python3 /srv/cray/scripts/google/update-dns.py; do
  sleep 5
done
systemctl restart cron
