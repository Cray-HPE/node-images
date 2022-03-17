#!/usr/bin/env bash

set -e

systemctl enable apache2
systemctl enable basecamp
systemctl enable conman
systemctl enable chronyd
systemctl enable dnsmasq
systemctl enable nexus
systemctl enable sshd
systemctl disable mdmonitor.service
systemctl disable mdmonitor-oneshot.service
systemctl disable mdcheck_start.service
systemctl disable mdcheck_continue.service