#!/bin/bash

set -e

kubernetes_version="1.20.13-0"
ceph_version='16.2.7.654+gd5a90ff46f0-lp153.3852.1'
ansible_version='2.9.21'
mkdir -p /etc/kubernetes
echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> /etc/profile.d/cray.sh

zypper addrepo https://download.opensuse.org/repositories/filesystems:ceph/openSUSE_Leap_15.3/filesystems:ceph.repo
zypper --gpg-auto-import-keys refresh
zypper install -y --recommends --force-resolution cephadm=16.2.7.654+gd5a90ff46f0-lp153.3852.1
zypper -n removerepo filesystems_ceph

echo "Moving ceph operations files into place"
mkdir -p /srv/cray/tmp
mkdir -p /srv/cray/tmp/storage_classes

echo "Creating directory for caching podman images"
image_dir="/srv/cray/resources/common/images/"
mkdir -p $image_dir

mv /srv/cray/resources/common/ansible/* /etc/ansible/

echo "Installing New Ansible Env"
pushd /etc/ansible
virtualenv boto3_ansible
. boto3_ansible/bin/activate
pip3 install ansible
pip3 install boto3
pip3 install netaddr
deactivate
popd

#echo "Installing ceph"
#zypper install -y --auto-agree-with-licenses \
#       python3-boto3 \
#       python3-xml \
#       python3-six \
#       python3-netaddr \
#       netcat \
#       jq \


echo "Pulling the ceph container image"
systemctl start podman

# Note to clean this up.  CASMINST-2148

podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7 registry.local/ceph/ceph:v16.2.7
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16 registry.local/ceph/ceph:v15.2.16
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0 registry.local/prometheus/alertmanager:v0.20.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0 registry.local/prometheus/alertmanager:v0.21.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2 registry.local/prometheus/node-exporter:v1.2.2
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2 registry.local/quay.io/prometheus/node-exporter:v1.2.2
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5 registry.local/ceph/ceph-grafana:8.3.5
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman pull artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4
podman tag  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4 registry.local/ceph/ceph-grafana:6.7.4
podman rmi  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4
podman pull artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1
podman tag  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1 registry.local/prometheus/prometheus:v2.18.1
podman tag  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1 registry.local/quay.io/prometheus/prometheus:v2.18.1 
podman rmi  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1

echo "Image pull complete"

echo "Saving ceph image to tar file as backup"
# Commenting out for troubleshooting.  will do a manual save per image for now.
#for image in $(podman images --format "{{.Repository}}")
# do
#  read -r name vers <<<$(podman images --format "{{.Repository}} {{.Tag}}" $image|grep registry)
#  read -r image_name <<<$(echo "$name"|awk -F"/" '{print $NF}')
#  echo "saving image $image_dir$image_name $vers"
#  podman save $name":"$vers -o "$image_dir$image_name"_$vers".tar"
# done

podman save registry.local/ceph/ceph:v16.2.7 -o /srv/cray/resources/common/images/ceph_v16.2.7.tar
podman save registry.local/ceph/ceph:v15.2.15 -o /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman save registry.local/ceph/ceph:v15.2.16 -o /srv/cray/resources/common/images/ceph_v15.2.16.tar
podman save registry.local/prometheus/alertmanager:v0.20.0 -o /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman save registry.local/prometheus/alertmanager:v0.21.0 -o /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman save registry.local/prometheus/node-exporter:v1.2.2 -o /srv/cray/resources/common/images/node-exporter_v1.2.2.tar
podman save registry.local/ceph/ceph-grafana:8.3.5 -o /srv/cray/resources/common/images/ceph-grafana_8.3.5.tar
podman save registry.local/ceph/ceph-grafana:6.7.4 -o /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar
podman save registry.local/prometheus/prometheus:v2.18.1 -o /srv/cray/resources/common/images/prometheus_v2.18.1.tar


# We may want to put a check in here for the files.

echo "Images have been saved for re-import post build"

echo "Stopping podman"
systemctl stop podman

echo "Disabling spire-agent.service"
systemctl disable spire-agent.service && systemctl stop spire-agent.service
