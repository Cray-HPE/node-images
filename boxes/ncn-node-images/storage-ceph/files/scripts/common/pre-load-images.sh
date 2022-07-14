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
podman rmi --all

podman image load -i /srv/cray/resources/common/images/registry_2.8.1.tar

mkdir -p /var/lib/registry

if  ! systemctl is-active registry.container.service
then
  systemctl enable registry.container.service
  systemctl start registry.container.service
fi


image_path="/srv/cray/resources/common/images/"
echo "Pre-loading local images"

podman image load -i /srv/cray/resources/common/images/ceph_v16.2.7.tar
podman image load -i /srv/cray/resources/common/images/ceph_v16.2.9.tar
podman image load -i /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman image load -i /srv/cray/resources/common/images/ceph_v15.2.16.tar
podman tag  registry.local/ceph/ceph:v15.2.16 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman tag  registry.local/ceph/ceph:v15.2.16 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman tag  registry.local/ceph/ceph:v15.2.15 artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman tag  registry.local/ceph/ceph:v15.2.16 artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman tag  registry.local/ceph/ceph:v16.2.7 artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman tag  registry.local/ceph/ceph:v16.2.9 artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.9
podman tag  registry.local/ceph/ceph:v15.2.16 localhost:5000/ceph/ceph:v15.2.16
podman tag  registry.local/ceph/ceph:v15.2.15 localhost:5000/ceph/ceph:v15.2.15
podman tag  registry.local/ceph/ceph:v16.2.7 localhost:5000/ceph/ceph:v16.2.7
podman tag  registry.local/ceph/ceph:v16.2.9 localhost:5000/ceph/ceph:v16.2.9

podman image load -i /srv/cray/resources/common/images/ceph-grafana_8.3.5.tar
podman tag registry.local/ceph/ceph-grafana:8.3.5 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman tag registry.local/ceph/ceph-grafana:8.3.5 artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman tag registry.local/ceph/ceph-grafana:8.3.5 registry.local/quay.io/ceph/ceph-grafana:8.3.5
podman tag registry.local/ceph/ceph-grafana:8.3.5 localhost:5000/ceph/ceph-grafana:8.3.5

podman image load -i /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar

podman image load -i /srv/cray/resources/common/images/prometheus_v2.18.1.tar
podman tag registry.local/prometheus/prometheus:v2.18.1  artifactory.algol60.net/csm-docker/stable/prometheus/prometheus:v2.18.1
podman tag registry.local/prometheus/prometheus:v2.18.1  localhost:5000/prometheus/prometheus:v2.18.1
podman tag registry.local/prometheus/prometheus:v2.18.1  localhost:5000/quay.io/prometheus/prometheus:v2.18.1

podman image load -i /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman tag registry.local/prometheus/alertmanager:v0.20.0 localhost:5000/quay.io/prometheus/alertmanager:v0.20.0
podman tag registry.local/prometheus/alertmanager:v0.20.0 localhost:5000/prometheus/alertmanager:v0.20.0

podman image load -i /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman tag registry.local/prometheus/alertmanager:v0.21.0 registry.local/quay.io/prometheus/alertmanager:v0.21.0
podman tag registry.local/prometheus/alertmanager:v0.21.0 localhost:5000/prometheus/alertmanager:v0.21.0
podman tag registry.local/prometheus/alertmanager:v0.21.0 localhost:5000/quay.io/prometheus/alertmanager:v0.21.0
podman tag registry.local/prometheus/alertmanager:v0.21.0 artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0

podman image load -i /srv/cray/resources/common/images/node-exporter_v1.2.2.tar
podman tag registry.local/prometheus/node-exporter:v1.2.2 registry.local/quay.io/prometheus/node-exporter:v1.2.2
podman tag registry.local/prometheus/node-exporter:v1.2.2 localhost:5000/prometheus/node-exporter:v1.2.2
podman tag registry.local/prometheus/node-exporter:v1.2.2 localhost:5000/quay.io/prometheus/node-exporter:v1.2.2
podman tag registry.local/prometheus/node-exporter:v1.2.2 artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2


podman push localhost:5000/ceph/ceph:v15.2.15
podman push localhost:5000/ceph/ceph:v15.2.16
podman push localhost:5000/ceph/ceph-grafana:8.3.5
podman push localhost:5000/ceph/ceph:v16.2.7
podman push localhost:5000/ceph/ceph:v16.2.9
podman push localhost:5000/prometheus/node-exporter:v1.2.2
podman push localhost:5000/quay.io/prometheus/node-exporter:v1.2.2
podman push localhost:5000/prometheus/alertmanager:v0.21.0
podman push localhost:5000/quay.io/prometheus/alertmanager:v0.21.0
podman push localhost:5000/prometheus/prometheus:v2.18.1
podman push localhost:5000/quay.io/prometheus/prometheus:v2.18.1
podman push localhost:5000/prometheus/alertmanager:v0.20.0

echo "Images loaded"
