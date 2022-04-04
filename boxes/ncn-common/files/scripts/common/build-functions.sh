#!/bin/bash

# TODO: eventually we shouldn't need any of this file as-is, pending proper internal
# artifact serving and mirroring, interconnect, etc. Virtual Shasta/Google Cloud can pull
# from the same place as builds for metal artifacts

function pre-pull-internal-images() {
  local image_names="$@"
  for image_name in $image_names; do
    if [ -f /etc/google_system ]; then
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
