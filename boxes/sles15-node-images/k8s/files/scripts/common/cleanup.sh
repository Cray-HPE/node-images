#!/usr/bin/env bash

set -e

# Because cloning a VM will make a new network interface
truncate -s 0 /etc/udev/rules.d/70-persistent-net.rules