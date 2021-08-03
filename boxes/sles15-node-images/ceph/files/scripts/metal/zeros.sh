#!/usr/bin/env bash

echo "running defrag this will take a while"
e4defrag / > /dev/null 2>&1
echo "write zeros...."
filler="$(($(df -BM --output=avail /|grep -v Avail|cut -d "M" -f1)-1024))"
dd if=/dev/zero of=/root/zero-file bs=1M count=$filler
rm /root/zero-file
