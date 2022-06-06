#!/bin/bash

function get_ip_from_metadata() {
  host=$1
  ip=$(cloud-init query ds | jq -r ".meta_data[].host_records[] | select(.aliases[]? == \"$host\") | .ip" 2>/dev/null)
  echo $ip
}

me=$(get_ip_from_metadata $(hostname).nmn)
vip=$(craysys metadata get k8s-virtual-ip)

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
