#!/usr/bin/env bash

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

backend rgw-backend
    option forwardfor
    balance static-rr
    option httpchk GET /"

for host in $(ceph orch ls rgw -f json-pretty|jq -r '.[].placement.hosts|map(.)|join(" ")')
do
 ip=$(get_ip_from_metadata $host.nmn)
 echo "        server server-$host-rgw0 $ip:8080 check weight 100"
done
