#!/bin/bash

set -e

echo "Moving ceph Google/Virtual Shasta operations files into place"
mv /srv/cray/resources/google/ansible/* /etc/ansible/

pip3 install ceph-deploy
