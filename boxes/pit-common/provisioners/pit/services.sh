#!/usr/bin/env bash

set -e

systemctl enable apache2
systemctl enable basecamp
systemctl enable chronyd
systemctl enable dnsmasq
systemctl enable nexus
systemctl enable sshd
systemctl stop mdmonitor
systemctl stop mdmonitor-oneshot
systemctl stop mdcheck_start
systemctl stop mdcheck_continue
systemctl disable mdmonitor
systemctl disable mdmonitor-oneshot
systemctl disable mdcheck_start
systemctl disable mdcheck_continue