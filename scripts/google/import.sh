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
set -e

if [ -z "$GOOGLE_CLOUD_SA_KEY" ]; then
  echo "Error: GOOGLE_CLOUD_SA_KEY must be defined"
  exit 1
fi
gcloud auth activate-service-account --key-file ${GOOGLE_CLOUD_SA_KEY}

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $this_dir/.variables

image_name_version="${image_name}-${version}"
if gcloud --project $google_destination_project_id compute images list --filter="name=${image_name_version}" | grep ${image_name_version} &>/dev/null; then
  echo "Google Cloud image $image_name_version already exists in $google_destination_project_id, not attempting an import"
  exit 0
fi
source_image="${image_name_version}.${qemu_format}"
destination_image="vshasta-$(printf ${image_name_version} | sed 's/-google//g')"
echo "Importing image ${source_image} into Google Cloud at ${google_destination_project_id}/${google_destination_image_family}/${destination_image}"
gcloud beta --project $google_destination_project_id compute images import \
  --source-file ${output_directory}/${source_image} \
  --os sles-15-byol \
  --family ${google_destination_image_family} \
  --network "${google_network}" \
  --subnet "${google_subnetwork}" \
  --zone ${google_zone} \
  --docker-image-tag latest \
  ${destination_image}
