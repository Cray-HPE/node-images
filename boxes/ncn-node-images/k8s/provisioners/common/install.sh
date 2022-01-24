#!/bin/bash

set -e

. /srv/cray/resources/common/vars.sh
kubernetes_version="${KUBERNETES_PULL_VERSION}-0"

echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> /etc/profile.d/cray.sh
mkdir -p /etc/kubernetes

echo "Initializing k8s directories and resources"
mkdir -p /etc/cray/kubernetes
echo "$kubernetes_version" | awk -F'-' '{print $1}' > /etc/cray/kubernetes/version
mkdir -p /etc/cray/kubernetes/flexvolume
# below are related to hostPath usage that should exist before k8s resources attempt to use them
mkdir -p /opt/cray/tbd
mkdir -p /var/run/sds


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
chmod 750 /usr/bin/velero

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

# The k8s rpm packages see "conntrack" as a required dependency, the sles/zypper repo that contains the actual required
# utils is not named that, so we're just making a dummy one of the expected name to ensure k8s rpm installs will work.
# Zypper doesn't seem to have a good automated way for us to ignore the missing dependency which would be the ideal way
# to handle this
echo "Building a custom local repository for conntrack dependency, just a mocked version of the named zypper package"
rm -rf /var/local-repos/conntrack/x86_64 || true
mkdir -p /tmp/conntrack
cat > /tmp/conntrack/conntrack.spec <<EOF
Name:     conntrack
Summary:  Dummy conntrack rpm for ensuring requirements in other packages
Version:  1
Release:  1
License:  none
%description
%prep
%build
%install
%files
EOF
rpmbuild -ba --define "_rpmdir /tmp/conntrack" /tmp/conntrack/conntrack.spec
mkdir -p /var/local-repos/conntrack/noarch
rm /tmp/conntrack/conntrack.spec
mv /tmp/conntrack/* /var/local-repos/conntrack/
createrepo /var/local-repos/conntrack
zypper -n removerepo local-conntrack || true
zypper -n addrepo --refresh --no-gpgcheck /var/local-repos/conntrack local-conntrack

zypper -n install --force -y conntrack-tools
zypper -n install --force -y \
  kubelet-${kubernetes_version} \
  kubeadm-${kubernetes_version} \
  kubectl-${kubernetes_version}

echo "Ensuring ipvs-required modules are loaded and will reload on reboot"
cat > /usr/lib/modules-load.d/01-ipvs.conf <<EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack_ipv4
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
pip3 install kubernetes

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
# crictl pull ${K8S_IMAGE_REGISTRY}/coredns:${COREDNS_PREVIOUS_VERSION}
# crictl pull ${K8S_IMAGE_REGISTRY}/kube-apiserver:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
# crictl pull ${K8S_IMAGE_REGISTRY}/kube-controller-manager:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
# crictl pull ${K8S_IMAGE_REGISTRY}/kube-scheduler:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
# crictl pull ${K8S_IMAGE_REGISTRY}/kube-proxy:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
# crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-npc:${WEAVE_PREVIOUS_VERSION}
# crictl pull ${DOCKER_IMAGE_REGISTRY}/weaveworks/weave-kube:${WEAVE_PREVIOUS_VERSION}
# crictl pull ${DOCKER_IMAGE_REGISTRY}/nfvpe/multus:${MULTUS_PREVIOUS_VERSION}
#
crictl pull k8s.gcr.io/coredns:${COREDNS_PREVIOUS_VERSION}
crictl pull k8s.gcr.io/kube-apiserver:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull k8s.gcr.io/kube-controller-manager:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull k8s.gcr.io/kube-scheduler:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull k8s.gcr.io/kube-proxy:"v${KUBERNETES_PULL_PREVIOUS_VERSION}"
crictl pull k8s.gcr.io/pause:"${PAUSE_VERSION}"
crictl pull docker.io/weaveworks/weave-npc:${WEAVE_PREVIOUS_VERSION}
crictl pull docker.io/weaveworks/weave-kube:${WEAVE_PREVIOUS_VERSION}
crictl pull docker.io/nfvpe/multus:${MULTUS_PREVIOUS_VERSION}

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
