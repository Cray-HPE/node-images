#!/bin/bash
echo "running vdisk defrag; this will take a while (it is worth it)"
e4defrag / > /dev/null 2>&1
echo "write zeros...."
filler="$(($(df -BM --output=avail /|grep -v Avail|cut -d "M" -f1)-1024))"
dd if=/dev/zero of=/root/zero-file bs=1M count=$filler
#rm /root/zero-file
