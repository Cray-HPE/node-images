#!/usr/bin/env bash

set -e

echo "Initializing directories and resources"

mkdir -p /srv/cray
cp -r /tmp/files/* /srv/cray/
chmod +x -R /srv/cray/scripts
rm -rf /tmp/files
