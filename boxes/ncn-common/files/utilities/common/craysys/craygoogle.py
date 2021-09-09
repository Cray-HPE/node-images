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
