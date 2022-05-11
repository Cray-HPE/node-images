#!/bin/bash
set -e

ANSIBLE_VERSION=${ANSIBLE_VERSION:-2.11.10}
REQUIREMENTS=( boto3 netaddr )

echo "Installing CSM Ansible $ANSIBLE_VERSION"
mkdir -pv /etc/ansible
pushd /etc/ansible
virtualenv csm_ansible
. csm_ansible/bin/activate
pip3 install ansible-core==$ANSIBLE_VERSION
pip3 install ansible

echo "Installing requirements: ${REQUIREMENTS[@]}"
for requirement in ${REQUIREMENTS[@]}; do
    pip3 install $requirement
done
deactivate
popd
