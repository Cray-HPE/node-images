#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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

. /srv/cray/resources/common/vars.sh

echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> /etc/profile.d/cray.sh
mkdir -p /etc/kubernetes

echo "Initializing k8s directories and resources"
mkdir -p /etc/cray/kubernetes
mkdir -p /etc/cray/kubernetes/flexvolume
# below are related to hostPath usage that should exist before k8s resources attempt to use them
mkdir -p /opt/cray/tbd
mkdir -p /var/run/sds
echo "${KUBERNETES_PULL_VERSION}" > /etc/cray/kubernetes/version

echo "Installing kata containers"
wget -q -c https://github.com/kata-containers/kata-containers/releases/download/${KATA_VERSION}/kata-static-${KATA_VERSION}-x86_64.tar.xz -O - | tar -xJ -C /

echo "Installing etcd binaries"
mkdir -p /tmp/etcd
wget -q -O /tmp/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
tar --no-overwrite-dir -C /tmp/etcd -xvzf /tmp/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
rm /tmp/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
cp /tmp/etcd/etcd-${ETCD_VERSION}-linux-amd64/etcd /usr/bin
cp /tmp/etcd/etcd-${ETCD_VERSION}-linux-amd64/etcdctl /usr/bin
chmod 750 /usr/bin/etcd
chmod 750 /usr/bin/etcdctl
rm -rf /tmp/etcd

echo "Installing the helm binary"
wget -q https://get.helm.sh/helm-v${HELM_V3_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/bin/helm
chmod +x /usr/bin/helm
helm version

echo "Installing Weave Net cli utility"
curl -L git.io/weave -o /usr/bin/weave
chmod a+x /usr/bin/weave

echo "Installing Velero cli utility"
wget -q "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz" -O - | tar -xzO "velero-${VELERO_VERSION}-linux-amd64/velero" > /usr/bin/velero
echo "Dowloading newer velero cli utiliy versions to support upgrades"
mkdir -p /srv/cray/tmp
wget -q "https://github.com/vmware-tanzu/velero/releases/download/v1.6.3/velero-v1.6.3-linux-amd64.tar.gz" -O /srv/cray/tmp/velero-v1.6.3-linux-amd64.tar.gz
wget -q "https://github.com/vmware-tanzu/velero/releases/download/v1.7.2/velero-v1.7.2-linux-amd64.tar.gz" -O /srv/cray/tmp/velero-v1.7.2-linux-amd64.tar.gz
chmod 750 /usr/bin/velero

echo "Ensuring ipvs-required modules are loaded and will reload on reboot"
cat > /usr/lib/modules-load.d/01-ipvs.conf <<EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
br_netfilter
EOF
modprobe $(tr '\n' ' '< /usr/lib/modules-load.d/01-ipvs.conf)

echo "Ensuring swap is off" && swapoff -a

echo "Installing containerd CRI and configuring the system for containerd"
wget -q -O /tmp/cri-containerd.tar.gz https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar --no-overwrite-dir -C / -xvzf /tmp/cri-containerd.tar.gz
rm /tmp/cri-containerd.tar.gz
ln -svnf /srv/cray/resources/common/containerd/containerd.service /etc/systemd/system/containerd.service
mkdir -p /etc/containerd
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "Installing kubernetes python client"
pip3 install --ignore-installed PyYAML
KUBELET_VER=$(rpm -qa | grep kubelet |  awk -F '-' '{print $2}')
K8S_MINOR_VERSION=$(echo $KUBELET_VER | awk -F '.' '{print $2}')
pip3 install "kubernetes==${K8S_MINOR_VERSION}.*" --upgrade

echo "Setting TasksMax to infinity via 10-kubelet.conf file"
mkdir -p /etc/systemd/system/kubelet.service.d
cp /srv/cray/resources/common/10-kubelet.conf /etc/systemd/system/kubelet.service.d/10-kubelet.conf

echo "Setting up /etc/cni/net.d/00-multus.conf file"
mkdir -p /etc/cni/net.d
cp /srv/cray/resources/common/containerd/00-multus.conf /etc/cni/net.d/00-multus.conf

echo "Setting up script to ensure multus file is populated after reboot"
cp /srv/cray/resources/common/multus/check-multus-file.sh /usr/bin
chmod 755 /usr/bin/check-multus-file.sh
echo "* * * * * root /usr/bin/check-multus-file.sh" > /etc/cron.d/check-multus-file

echo "Configuring rsyslog to suppress chatty messages"
cp /srv/cray/resources/common/rsyslog/ignore-systemd-session-slice.conf /etc/rsyslog.d/ignore-systemd-session-slice.conf
cp /srv/cray/resources/common/rsyslog/ignore-kubelet-noise.conf /etc/rsyslog.d/ignore-kubelet-noise.conf

echo "Setting up script to prune s3fs cache directory"
cp /srv/cray/resources/common/s3fs/prune-s3fs-cache.sh /usr/bin
chmod 755 /usr/bin/prune-s3fs-cache.sh

echo "Initially enabling services"
systemctl daemon-reload
systemctl enable kubelet containerd
systemctl start containerd

. /srv/cray/resources/common/vars.sh

echo "Pre-pulling images for previous version ceph provisioners (to support hybrid mode in upgrade)"
crictl pull k8s.gcr.io/sig-storage/csi-node-driver-registrar:v1.3.0
crictl pull k8s.gcr.io/sig-storage/csi-provisioner:v1.6.0
crictl pull k8s.gcr.io/sig-storage/csi-resizer:v0.5.0
crictl pull k8s.gcr.io/sig-storage/csi-snapshotter:v2.1.0
crictl pull quay.io/cephcsi/cephcsi:v3.1.1
crictl pull quay.io/k8scsi/csi-attacher:v2.1.1
crictl pull quay.io/k8scsi/csi-node-driver-registrar:v1.3.0
crictl pull quay.io/k8scsi/csi-provisioner:v1.6.0
crictl pull quay.io/k8scsi/csi-resizer:v0.5.0
crictl pull quay.io/k8scsi/csi-snapshotter:v2.1.0
crictl pull quay.io/k8scsi/csi-snapshotter:v2.1.1

echo "Pre-pulling images for current version ceph provisioners"
crictl pull ${K8S_IMAGE_REGISTRY}/sig-storage/csi-provisioner:v3.1.0
crictl pull ${K8S_IMAGE_REGISTRY}/sig-storage/csi-attacher:v3.4.0
crictl pull ${K8S_IMAGE_REGISTRY}/sig-storage/csi-snapshotter:v4.2.0
crictl pull ${K8S_IMAGE_REGISTRY}/sig-storage/csi-node-driver-registrar:v2.4.0
crictl pull ${K8S_IMAGE_REGISTRY}/sig-storage/csi-resizer:v1.3.0
crictl pull ${QUAY_IMAGE_REGISTRY}/cephcsi/cephcsi:v3.5.1

echo "Pre-pulling images for previous version of K8S (to support hybrid mode in upgrade)"
#
# Pull these in 1.3 when previous versions are in artifactory
# and match the previous version's manifests (and remove the ones
# that pull from upstream)
#
crictl pull ${K8S_IMAGE_REGISTRY}/coredns:${COREDNS_PREVIOUS_VERSION}
crictl pull ${K8S_IMAGE_REGISTRY}/kube-apiserver:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-controller-manager:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-scheduler:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-proxy:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-npc:${WEAVE_PREVIOUS_VERSION}
crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-kube:${WEAVE_PREVIOUS_VERSION}
crictl pull ${DOCKER_IMAGE_REGISTRY}/nfvpe/multus:${MULTUS_PREVIOUS_VERSION}

echo "Pre-pulling images for current version of K8S from artifactory"
crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-kube:${WEAVE_VERSION}
crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-npc:${WEAVE_VERSION}
crictl pull ${DOCKER_IMAGE_REGISTRY}/nfvpe/multus:${MULTUS_VERSION}
crictl pull ${K8S_IMAGE_REGISTRY}/coredns:${COREDNS_VERSION}
crictl pull ${K8S_IMAGE_REGISTRY}/kube-apiserver:"v${KUBERNETES_PULL_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-controller-manager:"v${KUBERNETES_PULL_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-scheduler:"v${KUBERNETES_PULL_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/kube-proxy:"v${KUBERNETES_PULL_VERSION}"
crictl pull ${K8S_IMAGE_REGISTRY}/pause:"${PAUSE_VERSION}"

echo "Displaying list of pre-cached images"

crictl images

echo "Writing docker registry sources to disk for use during cloud-init"
echo "export K8S_IMAGE_REGISTRY=${K8S_IMAGE_REGISTRY}" >> /srv/cray/resources/common/vars.sh
echo "export DOCKER_IMAGE_REGISTRY=${DOCKER_IMAGE_REGISTRY}" >> /srv/cray/resources/common/vars.sh
echo "export QUAY_IMAGE_REGISTRY=${QUAY_IMAGE_REGISTRY}" >> /srv/cray/resources/common/vars.sh
