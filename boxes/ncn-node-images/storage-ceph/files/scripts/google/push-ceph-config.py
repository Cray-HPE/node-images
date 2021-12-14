"""
Gets a list of workers and runs the ceph-deploy config push command

Copyright 2020, Cray Inc. All rights reserved.
"""

import os
from craysys.craygoogle import CrayGoogle

google = CrayGoogle()

project_id = google.get_metadata('/project-id')
instances_json = google.get_instances_json(project_id)

print('Finding instances with tag "worker"')
workers=[]
for zone in instances_json['items']:
  if 'instances' in instances_json['items'][zone]:
    for instance in instances_json['items'][zone]['instances']:
      if 'worker' in instance['tags']['items']:
        print('Found worker {}'.format(instance["name"]))
        workers.append(instance["name"])

# ceph-deploy must run in /etc/ceph
os.chdir('/etc/ceph')
os.system('/usr/bin/ceph-deploy --overwrite-conf config push '+' '.join(workers))
