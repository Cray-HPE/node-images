#!/bin/bash

image_path="/srv/cray/resources/common/images/"
echo "Pre-loading local images"
for image_file in $(ls $image_path)
 do
  read name version <<<$(echo $image_file|awk -F "_" '{print $(NF-1), $NF}');
  read tag <<<$(echo $version|awk -F".tar" '{print $(NF-1)}');
  echo "Loading image: $name  version: $tag"
  podman image load "registry.local/$name:$tag" -i $image_path$image_file
 done

echo "Images loaded"
