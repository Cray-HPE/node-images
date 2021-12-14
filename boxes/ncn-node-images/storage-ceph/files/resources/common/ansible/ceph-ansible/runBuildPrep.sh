#!/bin/sh

set -xe

zypper install -y ca-certificates-mozilla
zypper addrepo --no-gpgcheck https://download.opensuse.org/repositories/systemsmanagement/SLE_15_SP1/systemsmanagement.repo
zypper --gpg-auto-import-keys refresh
zypper install -y ansible
zypper install -y python3-devel

sed \
  -e '/^%global commit/d' \
  -e '/^%global shortcommit/d' \
  -e 's/%{shortcommit}/%{release}/' \
  -e 's/@VERSION@/4.0.0/' \
  -e 's/@RELEASE@/%(echo ${BUILD_METADATA})/' \
  -e '/^BuildArch:      noarch/d' \
  -e 's/cp group_vars\/rhcs.yml.sample/test -r group_vars\/rhcs.yml.sample \&\& cp group_vars\/rhcs.yml.sample/' \
  -e 's/^Name:.*$/Name: ceph-ansible-crayctldeploy/' \
  -e 's/%{_datarootdir}/\/opt\/cray/' \
  ceph-ansible.spec.in > ceph-ansible-crayctldeploy.spec

cat ceph-ansible-crayctldeploy.spec
