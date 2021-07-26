#!/usr/bin/env bash

# TODO: eventually we shouldn't need any of this file as-is, pending proper internal
# artifact serving and mirroring, interconnect, etc. Virtual Shasta/Google Cloud can pull
# from the same place as builds for metal artifacts

function pre-pull-internal-images() {
  local image_names="$@"
  for image_name in $image_names; do
    if [ -f /usr/bin/google_network_daemon ]; then
      # no need to truly pre-pull in these cases, we'll use runtime
      # auth to pull at that time for Google/Virtual Shasta
      echo "Delaying pre-pull of gcr.io/vshasta-cray/${image_name} to runtime"
    else
      location="arti.dev.cray.com/third-party-docker-stable-local/docker.io/${image_name}"
      echo "Pre-pulling internal image: $location"
      crictl pull $location
      new_location="docker.io/${image_name}"
      echo "Re-tagging image from: $location to $new_location"
      /usr/local/bin/ctr -n k8s.io images tag ${location} ${new_location}
      echo "Removing image: $location"
      /usr/local/bin/ctr -n k8s.io images rm ${location}
    fi
  done
}

function setup-dns() {
  if [ -f /usr/bin/google_network_daemon ]; then
    # TODO: the need for this may or may not go away depending where we land on DNS in GCP for the sake of the interconnect
    echo "Modifying DNS to use Cray DNS servers..."
    cp /etc/sysconfig/network/config /etc/sysconfig/network/config.backup
    sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*$|NETCONFIG_DNS_STATIC_SERVERS="172.31.84.40 172.30.84.40"|g' /etc/sysconfig/network/config
    systemctl restart network google-network-daemon
  fi
}

function cleanup-dns() {
  if [ -f /usr/bin/google_network_daemon ]; then
    # TODO: the need for this may or may not go away depending where we land on DNS in GCP for the sake of the interconnect
    mv /etc/sysconfig/network/config.backup /etc/sysconfig/network/config
  fi
}
