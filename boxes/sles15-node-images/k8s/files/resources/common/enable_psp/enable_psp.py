# Copyright 2021 Hewlett Packard Enterprise Development LP

import yaml

with open('/etc/kubernetes/manifests/kube-apiserver.yaml', 'r') as manifest_file:
    api_server_manifest = yaml.safe_load(manifest_file)

print('Original manifest:\n')
print(yaml.dump(api_server_manifest))

command = api_server_manifest['spec']['containers'][0]['command']

# Enable PodSecurityPolicy
try:
    enable_admission_plugins = [x for x in command if x.startswith('--enable-admission-plugins')][0]
    command.remove(enable_admission_plugins)
except IndexError:
    pass  # Didn't find --enable-admission-plugins parameter
command.append('--enable-admission-plugins=NodeRestriction,PodSecurityPolicy')

print('New manifest:\n')
print(yaml.dump(api_server_manifest))

with open('/etc/kubernetes/manifests/kube-apiserver.yaml', 'w') as manifest_file:
    manifest_file.write(yaml.dump(api_server_manifest))
