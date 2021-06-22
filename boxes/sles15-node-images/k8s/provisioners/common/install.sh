#!/bin/bash

set -e

etcd_version="v3.4.14"
kubernetes_version="1.19.9-0"
kubernetes_pull_version="v1.19.9"
containerd_version="1.4.3"
helm_v3_version="3.2.4"
velero_version="v1.5.2"
coredns_previous_version="1.6.7"
coredns_version="1.7.0"

. /srv/cray/scripts/common/build-functions.sh

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
wget -q -O /tmp/etcd/etcd-${etcd_version}-linux-amd64.tar.gz https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-amd64.tar.gz
tar --no-overwrite-dir -C /tmp/etcd -xvzf /tmp/etcd/etcd-${etcd_version}-linux-amd64.tar.gz
rm /tmp/etcd/etcd-${etcd_version}-linux-amd64.tar.gz
cp /tmp/etcd/etcd-v3.4.14-linux-amd64/etcd /usr/bin
cp /tmp/etcd/etcd-v3.4.14-linux-amd64/etcdctl /usr/bin
chmod 750 /usr/bin/etcd
chmod 750 /usr/bin/etcdctl
rm -rf /tmp/etcd

echo "Installing the helm binary"
wget -q https://get.helm.sh/helm-v${helm_v3_version}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/bin/helm
chmod +x /usr/bin/helm
helm version

echo "Installing Weave Net cli utility"
curl -L git.io/weave -o /usr/bin/weave
chmod a+x /usr/bin/weave

echo "Installing Velero cli utility"
wget -q "https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/velero-${velero_version}-linux-amd64.tar.gz" -O - | tar -xzO "velero-${velero_version}-linux-amd64/velero" > /usr/bin/velero
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
wget -q -O /tmp/cri-containerd.tar.gz https://github.com/containerd/containerd/releases/download/v${containerd_version}/cri-containerd-cni-${containerd_version}-linux-amd64.tar.gz
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

echo "Initially enabling services"
systemctl daemon-reload
systemctl enable kubelet containerd
systemctl start containerd

. /srv/cray/resources/common/vars.sh

echo "Pre-pulling previous version containerd images, will continue to retry if it fails..."
while ! kubeadm config images pull --kubernetes-version ${KUBERNETES_PULL_PREVIOUS_VERSION}; do
  sleep 5
done

echo "Pre-pulling containerd images, will continue to retry if it fails..."
while ! kubeadm config images pull --kubernetes-version ${KUBERNETES_PULL_VERSION}; do
  sleep 5
done

echo "Pre-pulling other images"
#
# docker.io rate limits us, let's pull weave from dtr...
#
pre-pull-internal-images weaveworks/weave-npc:${WEAVE_VERSION} weaveworks/weave-kube:${WEAVE_VERSION} nfvpe/multus:v3.1
crictl pull k8s.gcr.io/sig-storage/csi-provisioner:v1.6.0
crictl pull k8s.gcr.io/sig-storage/csi-attacher:v2.2.0
crictl pull k8s.gcr.io/sig-storage/csi-resizer:v0.5.0
crictl pull k8s.gcr.io/sig-storage/csi-snapshotter:v2.1.0
crictl pull k8s.gcr.io/sig-storage/csi-node-driver-registrar:v1.3.0
crictl pull k8s.gcr.io/coredns:${coredns_previous_version}
crictl pull k8s.gcr.io/coredns:${coredns_version}
crictl pull quay.io/cephcsi/cephcsi:v3.1.1

echo "Displaying list of pre-cached images"
crictl images
