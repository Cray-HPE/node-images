#!/usr/bin/env bash

set -e

echo "Waiting for YaST installation operations to complete..."
while ps aux | grep '[Y]aST2.call installation continue' &>/dev/null; do
  sleep 5
done
