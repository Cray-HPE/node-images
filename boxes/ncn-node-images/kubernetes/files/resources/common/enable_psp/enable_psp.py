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
