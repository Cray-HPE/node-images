#!/bin/bash

set -e

echo "Configuring nginx with single purpose of http health checks for the Kubernetes API server"
cat > /etc/nginx/nginx.conf <<EOF
worker_processes 1;
events {
worker_connections 1024;
use epoll;
}
http {
include           mime.types;
default_type      application/octet-stream;
keepalive_timeout 65;
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
    proxy_pass                    https://127.0.0.1:6443/healthz;
    proxy_ssl_trusted_certificate /etc/kubernetes/pki/ca.crt;
  }
}
}
EOF
nginx -t
