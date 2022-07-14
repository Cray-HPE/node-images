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
# Enables/disables the auditing software.
# If "ncn-mgmt-node-auditing-enabled": true then will copy configuration
# into place and restart the services, else will disable and stop the service
# Will be disables by default in vshasta

export CRAYSYS_TYPE=$(craysys type get)
if [ $CRAYSYS_TYPE != "google" ]; then
  export CRAYSYS_AUDITING=$(craysys metadata get ncn-mgmt-node-auditing-enabled)
fi

function configure_auditing() {
if [[ $CRAYSYS_AUDITING = "true" && $CRAYSYS_TYPE = "metal" ]]; then
  echo "Copying in Cray auditing config files"
  cp /srv/cray/resources/common/audit/* /etc/audit
  if [ ! -d /var/log/audit/HostOS ]; then
    echo "Create dir /var/log/audit/HostOS/"
    mkdir /var/log/audit/HostOS/
  fi
  echo "Restarting ncn auditing service"
  systemctl restart auditd.service
elif [[ $CRAYSYS_AUDITING = "false" && $CRAYSYS_TYPE = "metal" ]]; then
  echo "Using generic auditing configuration"
elif [ $CRAYSYS_TYPE = "google" ]; then
  echo "Disabling auditing on vshasta"
  systemctl disable auditd.service
  systemctl stop auditd.service
  systemctl status auditd.service --no-pager || echo "auditd.service is disabled"
fi
}
