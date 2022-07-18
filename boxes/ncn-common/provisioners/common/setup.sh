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
set -exu

# Find device and partition of /
cd /
df . | tail -n 1 | tr -s " " | cut -d " " -f 1 | sed -E -e 's/^([^0-9]+)([0-9]+)$/\1 \2/' |
if read DEV_DISK DEV_PARTITION_NR && [ -n "$DEV_PARTITION_NR" ]; then
  echo "Expanding $DEV_DISK partition $DEV_PARTITION_NR";
  sgdisk --move-second-header
  sgdisk --delete=${DEV_PARTITION_NR} "$DEV_DISK"
  sgdisk --new=${DEV_PARTITION_NR}:0:0 --typecode=0:8e00 ${DEV_DISK}
  partprobe "$DEV_DISK"

  resize2fs ${DEV_DISK}${DEV_PARTITION_NR}
fi

set +u

ANSIBLE_VERSION=${ANSIBLE_VERSION:-2.11.10}
REQUIREMENTS=( boto3 netaddr )

echo "Installing CSM Ansible $ANSIBLE_VERSION"
pip3 install --upgrade virtualenv
mkdir -pv /etc/ansible
python3 -m venv /etc/ansible/csm_ansible
. /etc/ansible/csm_ansible/bin/activate
pip3 install --upgrade pip
pip3 install ansible-core==$ANSIBLE_VERSION
pip3 install ansible

echo "Installing requirements: ${REQUIREMENTS[@]}"
for requirement in ${REQUIREMENTS[@]}; do
    pip3 install $requirement
done
deactivate
