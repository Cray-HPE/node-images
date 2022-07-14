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
"""
Gets a list of workers and runs the ceph-deploy config push command
"""

import os

from craysys.craygoogle import CrayGoogle

google = CrayGoogle()

project_id = google.get_metadata('/project-id')
instances_json = google.get_instances_json(project_id)

print('Finding instances with tag "worker"')
workers = []
for zone in instances_json['items']:
    if 'instances' in instances_json['items'][zone]:
        for instance in instances_json['items'][zone]['instances']:
            if 'worker' in instance['tags']['items']:
                print('Found worker {}'.format(instance["name"]))
                workers.append(instance["name"])

# ceph-deploy must run in /etc/ceph
os.chdir('/etc/ceph')
os.system(
    '/usr/bin/ceph-deploy --overwrite-conf config push ' + ' '.join(workers)
    )
