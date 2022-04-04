#!/usr/bin/env bash

set -ex

echo "Modifying DNS to use Google DNS servers..."
mv /etc/sysconfig/network/config.backup /etc/sysconfig/network/config