#!/bin/bash

# RPM Packages Installed By Inventory:
# NOTE: CSM has taken over the following remaining packages from COS.
#
#     acpid:
#         Purpose: Used to inform user-space programs about ACPI events.
#
#     cray-auth-utils:
#         Purpose: Required by packages used to provide support for heartbeat
#
#     cray-heartbeat:
#         Purpose: Used to provide heartbeat from the node. The Hardware State
#                  Manager stores the state of the NCN based on the presence of
#                  this signaling.
#
#     cray-node-identity:
#         Purpose: Used to provide xname on node. Required by heartbeat, which
#                  is in turn used by the Data Virtualization Service (DVS) on
#                  worker nodes.
#
#########################################################################

set -e

echo "Enabling HPE Cray OS services"
systemctl enable acpid.service
systemctl enable cray-heartbeat.service
# FIXME "causing build failures on main:release/1.2": systemctl enable cray-node-identity.service

echo "Setting up rsyslog"
/srv/cray/scripts/commong/cos/rsyslog.sh