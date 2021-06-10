#!/bin/bash

echo "Checking that 00-multus.conf file is in place and not empty"
if [ -f /etc/cni/net.d/00-multus.conf ] && [ ! -s /etc/cni/net.d/00-multus.conf ]; then
  echo "Replacing zero length file 00-multus.conf "
  cp /srv/cray/resources/common/containerd/00-multus.conf /etc/cni/net.d/00-multus.conf
fi
