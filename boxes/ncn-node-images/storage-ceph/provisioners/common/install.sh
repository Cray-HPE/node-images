#!/bin/bash

set -e

kubernetes_version="1.20.13-0"
ceph_version='15.2.14.84+gb6e5642e260-3.31.1'
ansible_version='2.9.21'
mkdir -p /etc/kubernetes
echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> /etc/profile.d/cray.sh

echo "Moving ceph operations files into place"
mkdir -p /etc/ansible
mkdir -p /srv/cray/tmp
mkdir -p /srv/cray/tmp/storage_classes
mkdir -p /etc/ansible

echo "Creating directory for caching pomdan images"
image_dir="/srv/cray/resources/common/images/"
mkdir -p $image_dir

mv /srv/cray/resources/common/ansible/* /etc/ansible/

echo "Installing Ansible"
pushd /etc/ansible
pip3 install virtualenv
virtualenv boto3_ansible
. boto3_ansible/bin/activate
pip3 install ansible
pip3 install boto3
pip3 install netaddr
deactivate
popd

echo "Installing ceph"
zypper install -y --auto-agree-with-licenses \
       python3-boto3 \
       python3-xml \
       python3-six \
       python3-netaddr \
       netcat \
       jq \
       ceph-common-$ceph_version \
       cephadm

echo "Pulling the ceph container image"
systemctl start podman

# Note to clean this up.  CASMINST-2148

podman pull artifactory.algol60.net/csm-docker/stable/ceph/ceph:v15.2.8
podman tag  artifactory.algol60.net/csm-docker/stable/ceph/ceph:v15.2.8 registry.local/ceph/ceph:v15.2.8
podman rmi  artifactory.algol60.net/csm-docker/stable/ceph/ceph:v15.2.8
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0 registry.local/prometheus/alertmanager:v0.20.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0 registry.local/prometheus/alertmanager:v0.21.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2 registry.local/prometheus/node-exporter:v1.2.2
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
podman pull artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.6.2
podman tag  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.6.2 registry.local/ceph/ceph-grafana:6.6.2
podman rmi  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.6.2
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

podman save registry.local/ceph/ceph:v15.2.8 -o /srv/cray/resources/common/images/ceph_v15.2.8.tar
podman save registry.local/ceph/ceph:v15.2.15 -o /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman save registry.local/prometheus/alertmanager:v0.20.0 -o /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman save registry.local/prometheus/alertmanager:v0.21.0 -o /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman save registry.local/prometheus/node-exporter:v1.2.2 -o /srv/cray/resources/common/images/node-exporter_v1.2.2.tar
podman save registry.local/ceph/ceph-grafana:6.6.2 -o /srv/cray/resources/common/images/ceph-grafana_6.6.2.tar
podman save registry.local/ceph/ceph-grafana:6.7.4 -o /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar
podman save registry.local/prometheus/prometheus:v2.18.1 -o /srv/cray/resources/common/images/prometheus_v2.18.1.tar


# We may want to put a check in here for the files.

echo "Images have been saved for re-import post build"

echo "Stopping podman"
systemctl stop podman

echo "Ensuring that the kubernetes package repo exists in zypper"
if ! zypper repos | grep google-kubernetes; then
  zypper addrepo --gpgcheck-strict --refresh https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 google-kubernetes
fi
echo "Ensuring that we have the necessary gpg keys from google-kubernetes repo"
rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg
curl -o /tmp/apt-key.gpg.asc https://packages.cloud.google.com/yum/doc/apt-key.gpg.asc
echo "" >> /tmp/apt-key.gpg.asc
rpm --import /tmp/apt-key.gpg.asc
zypper refresh google-kubernetes

zypper install -y kubectl-${kubernetes_version}

zypper -n removerepo google-kubernetes || true

echo "Disabling spire-agent.service"
systemctl disable spire-agent.service && systemctl stop spire-agent.service
