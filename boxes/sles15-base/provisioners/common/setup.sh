#!/bin/bash

set -e
# Sometimes AutoYaST and dracut are still running some operations after the install has finished. 
# If the VM image starts saving before either finishes the build will fail.

echo "Waiting for dracut operations to finish ..."
while ps aux | grep 'dracut' | grep -v grep &>/dev/null; do
    sleep 5
done

echo "Waiting for YaST installation operations to complete ..."
while ps aux | grep '[Y]aST2.call installation continue' &>/dev/null; do
    sleep 5
done
