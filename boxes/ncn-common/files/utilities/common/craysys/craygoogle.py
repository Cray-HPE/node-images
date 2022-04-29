#  MIT License
#
#  (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
#  Permission is hereby granted, free of charge, to any person obtaining a
#  copy of this software and associated documentation files (the "Software"),
#  to deal in the Software without restriction, including without limitation
#  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#  and/or sell copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
#  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.

import requests
import sys
import json


class CrayGoogle:

    def get_metadata(self, key, level='system'):
        # retrieve metadata at the project level by default
        base_url = 'http://metadata.google.internal/computeMetadata/v1/project'
        if level == 'node':
            # retrieve from GCP instance metadata
            base_url = 'http://metadata.google.internal/computeMetadata/v1/instance'
        if '/' not in key:
            key = '/attributes/{}'.format(key)
        try:
            resp = requests.get(
                '{}{}'.format(base_url, key),
                headers={'Metadata-Flavor': 'Google'}
            )
            resp.raise_for_status()
            return resp.text
        except Exception as e:
            sys.exit('Error getting metadata value: {}'.format(e))

    def get_access_token(self):
        token_resp = self.get_metadata('/service-accounts/default/token', 'node')
        token_resp_json = json.loads(token_resp)
        return token_resp_json['access_token']

    def get_instances_json(self, project_id, access_token=None):
        if not access_token:
            access_token = self.get_access_token()
        try:
            resp = requests.get(
                'https://compute.googleapis.com/compute/v1/projects/{}/aggregated/instances'.format(project_id),
                headers={'Authorization': 'Bearer {}'.format(access_token)}
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            sys.exit('Error getting instances json: {}'.format(e))
