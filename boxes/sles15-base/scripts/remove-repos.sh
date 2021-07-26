#!/usr/bin/env bash

set -e

zypper -n rr buildonly-cray-sle-module-basesystem
zypper -n rr buildonly-cray-sle-module-basesystem-debug
zypper -n rr buildonly-cray-sle-module-public-cloud
zypper -n rr buildonly-cray-sle-module-basesystem-updates
zypper -n rr buildonly-cray-sle-module-basesystem-updates-debug
zypper -n rr buildonly-cray-sle-module-public-cloud-updates
zypper -n clean --all
