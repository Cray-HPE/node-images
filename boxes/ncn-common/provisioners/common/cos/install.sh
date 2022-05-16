#!/bin/bash

# RPM Packages Installed By Inventory:
# NOTE: CSM has taken over the following remaining packages from COS.
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
