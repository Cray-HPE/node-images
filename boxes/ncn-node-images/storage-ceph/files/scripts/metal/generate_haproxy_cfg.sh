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

echo "# Please do not change this file directly since it is managed by Ansible and will be overwritten
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     8000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
    tune.ssl.default-dh-param 4096
    ssl-default-bind-ciphers EECDH+AESGCM:EDH+AESGCM
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 8000

frontend http-rgw-frontend
    bind *:80
    default_backend rgw-backend

frontend https-rgw-frontend
    bind *:443 ssl crt /etc/ceph/rgw.pem
    default_backend rgw-backend

frontend dashboard_front_ssl
  mode tcp
  bind *:3444 ssl crt /etc/ceph/rgw.pem
  default_backend dashboard_back_ssl

frontend grafana-frontend
    mode tcp
    bind *:3080
    option tcplog
    redirect scheme https code 301 if !{ ssl_fc }
    default_backend grafana-backend

backend rgw-backend
    option forwardfor
    balance static-rr
    option httpchk GET /"

for host in $(ceph --name client.ro orch ls rgw -f json-pretty|jq -r '.[].placement.hosts|map(.)|join(" ")')
do
 ip=$(get_ip_from_metadata $host.nmn)
 echo "        server server-$host-rgw0 $ip:8080 check weight 100"
done

echo -e "\nbackend grafana-backend
    mode tcp
    option httpchk GET /
    http-check expect status 200"

for host in $(ceph --name client.ro orch ls mgr -f json-pretty|jq -r '.[].placement.hosts|map(.)|join(" ")')
do
 ip=$(get_ip_from_metadata $host.nmn)
 echo "        server server-$host-mgr $ip:3000 check weight 100"
done

echo -e "\nbackend dashboard_back_ssl
  mode tcp
  option httpchk GET /
  http-check expect status 200"

for host in $(ceph --name client.ro orch ls mgr -f json-pretty|jq -r '.[].placement.hosts|map(.)|join(" ")')
do
 ip=$(get_ip_from_metadata $host.nmn)
 echo "        server server-$host-mgr $ip:8443 check weight 100"
done
