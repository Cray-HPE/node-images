#!/bin/bash

# RPM Packages Installed By Inventory:
# NOTE: CSM has taken over the following remaining packages from COS.
#
#     acpid:
#         Purpose: Used to inform user-space programs about ACPI events.
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
systemctl enable csm-node-identity.service

# rsyslog config to ensure the NCN OS logs are routed to SMF
cat << EOF > /etc/rsyslog.d/01-cray-rsyslog.conf
*.* action(
  type="omfwd"    target="rsyslog-aggregator.nmnlb"
  port="514"
  protocol="tcp"
  template="RSYSLOG_SyslogProtocol23Format"
)
EOF
chmod 600 /etc/rsyslog.d/01-cray-rsyslog.conf
