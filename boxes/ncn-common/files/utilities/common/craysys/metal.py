import json
import subprocess
import sys

class Metal:

    def execute(self, cmd):
        process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (result, error) = process.communicate()
        rc = process.wait()
        if rc != 0:
            print("Error: failed to execute cmd:", cmd, error)
        return json.loads(result)

    def get_metadata(self, key, level='system'):
        try:
            # cloud-init <22.0 converts dashes, so we'll do the same
            #
            # NOTE: When using cloud-init 22 or higher this replacement should
            #       be removed.
            key = key.replace('-', '_')
            resp = self.execute("cloud-init query -a")
            if level == 'node':
                return resp['ds']['meta_data'][key]
            else:
                return resp['ds']['meta_data']['Global'][key]
        except Exception as e:
            sys.exit('Error getting metadata value: {}'.format(e))
