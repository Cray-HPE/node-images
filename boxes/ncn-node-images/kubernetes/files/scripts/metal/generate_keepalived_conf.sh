#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
function get_ip_from_metadata() {
  host=$1
  ip=$(cloud-init query ds | jq -r ".meta_data[].host_records[] | select(.aliases[]? == \"$host\") | .ip" 2>/dev/null)
  echo $ip
}

me=$(get_ip_from_metadata $(hostname).nmn)
vip=$(craysys metadata get k8s_virtual_ip)

echo "vrrp_script haproxy-check {
    script "/usr/bin/kill -0 haproxy"
    interval 2
    weight 20
}

vrrp_instance kube-apiserver-nmn-vip {
    state BACKUP
    priority 101
    interface bond0.nmn0
    virtual_router_id 47
    advert_int 3

    unicast_src_ip $me
    unicast_peer {"

for x in `seq 5`
do
  ip=$(get_ip_from_metadata ncn-m00$x.nmn)
  if [ "$ip" != "" ] && [ "$ip" != "$me" ]; then
    echo "       $ip"
  fi
done

echo "    }

    virtual_ipaddress {
        $vip
    }

    track_script {
        haproxy-check weight 20
    }
}"
