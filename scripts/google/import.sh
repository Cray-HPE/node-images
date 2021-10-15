#!/bin/bash

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
destination_image="vshasta-${image_name_version}"
echo "Importing image ${source_image} into Google Cloud at ${google_destination_project_id}/${google_destination_image_family}/${destination_image}"
gcloud --project $google_destination_project_id compute images import \
  --source-file ${output_directory}/${source_image} \
  --os sles-15-byol \
  --family ${google_destination_image_family} \
  --network "${google_network}" \
  --subnet "${google_subnetwork}" \
  --zone ${google_zone} \
  ${destination_image}
