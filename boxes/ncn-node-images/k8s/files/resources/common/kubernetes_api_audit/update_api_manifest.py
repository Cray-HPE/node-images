
# Copyright 2020 Hewlett Packard Enterprise Development LP

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
