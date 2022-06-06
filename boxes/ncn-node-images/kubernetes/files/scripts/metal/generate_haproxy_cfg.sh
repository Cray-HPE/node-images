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
vip=$(craysys metadata get k8s-virtual-ip)

echo "global
  log /dev/log daemon
  maxconn 32768
  chroot /var/lib/haproxy
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats user haproxy group haproxy mode 0640 level operator
  tune.bufsize 32768
  tune.ssl.default-dh-param 2048
  ssl-default-bind-ciphers ALL:!aNULL:!eNULL:!EXPORT:!DES:!3DES:!MD5:!PSK:!RC4:!ADH:!LOW@STRENGTH

defaults
  log     global
  mode    http
  option  log-health-checks
  option  log-separate-errors
  option  dontlog-normal
  option  dontlognull
  option  httplog
  option  socket-stats
  retries 3
  option  redispatch
  maxconn 10000
  timeout connect   10s
  timeout client    600s
  timeout server    600s

listen stats
  bind 127.0.0.1:2382
  stats enable
  stats uri     /
  stats refresh 5s
  rspadd Server:\ haproxy/1.6

frontend k8s-api-nmn
    bind ${vip}:6442
    option tcplog
    mode tcp
    default_backend k8s-api

backend k8s-api
    mode tcp
    option httpchk GET /readyz HTTP/1.0
    option  log-health-checks
    http-check expect status 200
    balance roundrobin
    default-server verify none check-ssl inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
"

for x in `seq 5`
do
  ip=$(get_ip_from_metadata ncn-m00$x.nmn)
  if [ "$ip" != "" ] ; then
    echo "    server k8s-api-$x $ip:6443 check"
  fi
done

echo "
frontend etcd
    bind 127.0.0.1:2381
    option tcplog
    mode tcp
    default_backend etcd

backend etcd
    mode tcp
    balance roundrobin
    option tcp-check
"

for x in `seq 5`
do
  ip=$(get_ip_from_metadata ncn-m00$x.nmn)
  if [ "$ip" != "" ] ; then
    if [ "$ip" == "$me" ]; then
      echo "    server etcd$x $ip:2379 check weight 10"
    else
      echo "    server etcd$x $ip:2379 check weight 100"
    fi
  fi
done
