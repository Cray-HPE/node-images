#!/usr/bin/env bash

# Install Testing RPM Packages Installed By Inventory
#
#     csm-testing
#         Purpose: Provides Goss tests that run pre-flight checks to test
#                  whether services on the LiveCD node and NCNs are
#                  functioning as expected.
##
#     hpe-csm-goss-package
#         Purpose: Provides Goss package.
##
#     hpe-csm-yq-package
#         Purpose: Provides yq package.
#
#     goss-servers
#         Purpose: Installs the systemd unit file for the goss-servers
#                  service which starts any Goss servers defined in the included
#                  shell script (/usr/sbin/start-goss-servers.sh).

# set the environment variable for the base location of testing files (used by some tests)
export GOSS_BASE=/opt/cray/tests/install/ncn

echo "Enabling goss-servers systemd service"
systemctl enable goss-servers.service \
  || echo 'weird... oh well please continue the build for development efforts and sleep schedules'
