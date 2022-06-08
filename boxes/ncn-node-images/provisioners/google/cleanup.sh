#!/usr/bin/env bash

set -ex

# NOTE: This is restored because the DNS is only used during image building
echo "Modifying DNS to use Google DNS servers..."
mv /etc/sysconfig/network/config.backup /etc/sysconfig/network/config
