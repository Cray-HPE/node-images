"""
Updates the dns configuration for a node based on expected Virtual Shasta project/nodes config

Copyright 2019, Cray Inc. All rights reserved.
"""

import requests
import re
import hashlib
import os
from craysys.craygoogle import CrayGoogle

google = CrayGoogle()

project_id = google.get_metadata('/project-id')
instance_name = google.get_metadata('/name', 'node')
instances_json = google.get_instances_json(project_id)

print('Determining domain from metadata: ', end='', flush=True)
domain = google.get_metadata('domain')

print('Finding local DNS server(s) by instance tag "dns-server"')
dns_servers=[]
for zone in instances_json['items']:
  if 'instances' in instances_json['items'][zone]:
    for instance in instances_json['items'][zone]['instances']:
      if 'dns-server' in instance['tags']['items']:
        first_nic_internal_ip = instance['networkInterfaces'][0]['networkIP']
        print('Found local DNS server {} with internal IP {}'.format(instance['name'], first_nic_internal_ip))
        dns_servers.append(first_nic_internal_ip)

net_config_checksum = ""
updated_net_config_checksum = ""
with open('/etc/sysconfig/network/config', 'r+') as net_config:
  data = net_config.read()
  net_config_checksum = hashlib.md5(data.encode('utf-8')).hexdigest()
  net_config.seek(0)
  new_content = re.sub(r'^NETCONFIG_DNS_STATIC_SERVERS=.*$', 'NETCONFIG_DNS_STATIC_SERVERS="{}"'.format(' '.join(dns_servers)), data, flags=re.M)
  net_config.write(re.sub(r'^NETCONFIG_DNS_STATIC_SEARCHLIST=.*$', 'NETCONFIG_DNS_STATIC_SEARCHLIST="{}"'.format(domain), new_content, flags=re.M))
  net_config.truncate()

with open('/etc/sysconfig/network/config', 'r+') as net_config:
  data = net_config.read()
  updated_net_config_checksum = hashlib.md5(data.encode('utf-8')).hexdigest()

if net_config_checksum != updated_net_config_checksum:
  print('Restarting network to pick up changes to net config...', end='', flush=True)
  os.system('systemctl restart network')
  print('done')
