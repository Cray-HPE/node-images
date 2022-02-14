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

podman image load registry.local/ceph/ceph:v15.2.8 -i /srv/cray/resources/common/images/ceph_v15.2.8.tar
podman image load registry.local/ceph/ceph:v15.2.15 -i /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman image load registry.local/ceph/ceph-grafana:6.6.2 -i /srv/cray/resources/common/images/ceph-grafana_6.6.2.tar
podman image load registry.local/ceph/ceph-grafana:6.7.4 -i /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar
podman image load registry.local/quay.io/prometheus/prometheus:v2.18.1 -i /srv/cray/resources/common/images/prometheus_v2.18.1.tar
podman image load registry.local/quay.io/prometheus/alertmanager:v0.20.0 -i /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman image load registry.local/quay.io/prometheus/alertmanager:v0.21.0 -i /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman image load registry.local/quay.io/prometheus/node-exporter:v0.18.1 -i /srv/cray/resources/common/images/node-exporter_v0.18.1.tar
podman image load registry.local/quay.io/prometheus/node-exporter:v1.2.2 -i /srv/cray/resources/common/images/node-exporter_v1.2.2.tar

echo "Images loaded"
