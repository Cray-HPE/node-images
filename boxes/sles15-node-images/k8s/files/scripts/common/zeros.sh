#!/bin/bash

echo "Running defrag -- this will take a while"
e4defrag / > /dev/null 2>&1
echo "Write zeros..."
filler="$(($(df -BM --output=avail /|grep -v Avail|cut -d "M" -f1)-1024))"
dd if=/dev/zero of=/root/zero-file bs=1M count=$filler
