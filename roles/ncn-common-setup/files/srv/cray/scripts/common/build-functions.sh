#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

# TODO: eventually we shouldn't need any of this file as-is, pending proper internal
# artifact serving and mirroring, interconnect, etc. Virtual Shasta/Google Cloud can pull
# from the same place as builds for metal artifacts

function pre-pull-internal-images() {
  #shellcheck disable=SC2124
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
