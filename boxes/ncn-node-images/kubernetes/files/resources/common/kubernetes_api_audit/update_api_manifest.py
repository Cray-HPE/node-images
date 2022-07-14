#!/usr/bin/python3
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
import yaml

with open('/etc/kubernetes/manifests/kube-apiserver.yaml', 'r') as manifest_file:
    api_server_manifest = yaml.safe_load(manifest_file)

print('Original manifest:\n')
print(yaml.dump(api_server_manifest))

command = api_server_manifest['spec']['containers'][0]['command']

# add/set the --audit-log-path parameter
try:
    audit_log_path_entry = [x for x in command if x.startswith('--audit-log-path=')][0]
    command.remove(audit_log_path_entry[0])
except IndexError:
    pass  # Didn't find --audit-log-path parameter
command.append('--audit-log-path=/var/log/audit/kl8s/apiserver/audit.log')

# add/set the --audit-policy-file parameter
try:
    audit_policy_file_entry = [x for x in command if x.startswith('--audit-policy-file=')][0]
    command.remove(audit_policy_file_entry)
except IndexError:
    pass  # Didn't find --audit-policy-file parameter
command.append('--audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml')

# add/set the --audit-log-maxbackup parameter
try:
    audit_log_maxbackup_entry = [x for x in command if x.startswith('--audit-log-maxbackup=')][0]
    command.remove(audit_log_maxbackup_entry)
except IndexError:
    pass  # Didn't find --audit-log-maxbackup parameter
command.append('--audit-log-maxbackup=100')

# add/set the volume for the audit config file
volumes = api_server_manifest['spec']['volumes']
try:
    audit_config_file_volume_entry = [x for x in volumes if x['name'] == 'k8s-audit'][0]
    volumes.remove(audit_config_file_volume_entry)
except IndexError:
    pass  # Didn't find k8s-audit.
volumes.append({
    'name': 'k8s-audit',
    'hostPath': {'path': '/etc/kubernetes/audit', 'type': 'DirectoryOrCreate'}})

# add/set the volume for the audit log directory
try:
    audit_log_volume_entry = [x for x in volumes if x['name'] == 'k8s-audit-log'][0]
    volumes.remove(audit_log_volume_entry)
except IndexError:
    pass  # Didn't find k8s-audit-log
volumes.append({
    'name': 'k8s-audit-log',
    'hostPath': {'path': '/var/log/audit/kl8s/apiserver', 'type': 'DirectoryOrCreate'}})

# add/set the volumeMount for the audit config file
volume_mounts = api_server_manifest['spec']['containers'][0]['volumeMounts']
try:
    audit_config_file_vm_entry = [x for x in volume_mounts if x['name'] == 'k8s-audit'][0]
    volume_mounts.remove(audit_config_file_vm_entry)
except IndexError:
    pass  # Didn't find k8s-audit
volume_mounts.append({'name': 'k8s-audit', 'mountPath': '/etc/kubernetes/audit', 'readOnly': True})

# add/set the volumeMount for the audit log directory
try:
    audit_log_vm_entry = [x for x in volume_mounts if x['name'] == 'k8s-audit-log'][0]
    volume_mounts.remove(audit_log_vm_entry)
except IndexError:
    pass  # Didn't find k8s-audit-log
volume_mounts.append({'name': 'k8s-audit-log', 'mountPath': '/var/log/audit/kl8s/apiserver', 'readOnly': False})

print('New manifest:\n')
print(yaml.dump(api_server_manifest))

with open('/etc/kubernetes/manifests/kube-apiserver.yaml', 'w') as manifest_file:
    manifest_file.write(yaml.dump(api_server_manifest))
