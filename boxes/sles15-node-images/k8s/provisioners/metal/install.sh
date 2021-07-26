#!/usr/bin/env bash
#
# HPE Cray Metal services and apps used to support kubernetes.
#
# RPM Packages Installed By Inventory
#
#     haproxy:
#         Purpose: Installs haproxy for k8s routing.
#
#     keepalived:
#         Purpose: Installs keepalived for k8s connections.
#
#     dracut-metal-dmk8s:
#         Purpose: Configures partitions for kubernetes.
#
#########################################################################

set -e

# Adding sysctl vars for metal.
cp -pvr /srv/cray/sysctl/metal/* /etc/sysctl.d/

echo "Loading in sysctl settings; activating for build-time"
sysctl -p

# Adding tmpfiles for metal.
cp -pvr /srv/cray/resources/metal/tmpfiles.d/* /usr/lib/tmpfiles.d/

# Adding cloud-init.cfg files for metal.
cp -pvr /srv/cray/resources/metal/cloud.cfg.d/* /etc/cloud/cloud.cfg.d/

# Create directories for mountpoints (skip existing).
# lib-containerd will be an overlayfs, this will allow the added block-device to be transparent to
# existing files.
cp -p /srv/cray/resources/metal/metalfs.service /usr/lib/systemd/system
systemctl enable metalfs

# enable this to run on first boot during deployment, and then the kdump script disables it
systemctl enable kdump-cray
