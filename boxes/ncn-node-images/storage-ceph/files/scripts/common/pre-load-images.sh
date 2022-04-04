#!/bin/bash

image_path="/srv/cray/resources/common/images/"
echo "Pre-loading local images"
#for image_file in $(ls $image_path)
# do
#  read name version <<<$(echo $image_file|awk -F "_" '{print $(NF-1), $NF}');
#  read tag <<<$(echo $version|awk -F".tar" '{print $(NF-1)}');
#  echo "Loading image: $name  version: $tag"
#  podman image load "registry.local/$name:$tag" -i $image_path$image_file
# done

podman image load -i /srv/cray/resources/common/images/ceph_v15.2.8.tar
podman image load -i /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman tag  registry.local/ceph/ceph:v15.2.15 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman image load -i /srv/cray/resources/common/images/ceph-grafana_6.6.2.tar
podman image load -i /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar
podman image load -i /srv/cray/resources/common/images/prometheus_v2.18.1.tar
podman image load -i /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman image load -i /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman tag registry.local/prometheus/alertmanager:v0.21.0 registry.local/quay.io/prometheus/alertmanager:v0.21.0
podman image load -i /srv/cray/resources/common/images/node-exporter_v1.2.2.tar
podman tag registry.local/prometheus/node-exporter:v1.2.2 registry.local/quay.io/prometheus/node-exporter:v1.2.2

echo "Images loaded"
