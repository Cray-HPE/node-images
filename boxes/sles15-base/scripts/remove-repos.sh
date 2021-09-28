#!/bin/bash

set -e

zypper -n rr buildonly-cray-sle-module-basesystem
zypper -n rr buildonly-cray-sle-module-basesystem-debug
zypper -n rr buildonly-cray-sle-module-public-cloud
zypper -n rr buildonly-cray-sle-module-basesystem-updates
zypper -n rr buildonly-cray-sle-module-basesystem-updates-debug
zypper -n rr buildonly-cray-sle-module-public-cloud-updates
zypper -n clean --all

zypper rs Basesystem_Module_15_SP2_x86_64
zypper rs Public_Cloud_Module_15_SP2_x86_64
zypper rs SUSE_Linux_Enterprise_Server_15_SP2_x86_64
zypper rs Server_Applications_Module_15_SP2_x86_64
