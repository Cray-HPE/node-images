#!/bin/bash

# this script can either be called at runtime coupled with a network restart
# or as part of a build at a topmost layer. If it's called at any lower layer build, the build
# network for layers above will be broken

echo 'Dumping current settings for DNS:'
cat /etc/resolv.conf
grep NETCONFIG_DNS_STATIC_SERVERS /etc/sysconfig/network/config
grep NETCONFIG_DNS_STATIC_SEARCHLIST /etc/sysconfig/network/config

echo 'Setting new DNS'
# Can give multiple DNS in the form of a single-quoted string.
dns_server_ip=$(craysys metadata get dns-server || echo -n '' )
domain=$(craysys metadata get domain || echo -n '' )
# Only update static servers when provided, otherwise we risk overwriting with bad values.
if [[ -n $dns_server_ip ]]; then
  sed -i 's/NETCONFIG_DNS_STATIC_SERVERS=.*/NETCONFIG_DNS_STATIC_SERVERS=\"'"${dns_server_ip}"'\"/' /etc/sysconfig/network/config
fi
# Only update domain searchlist when provided, otherwise we risk overwriting with bad values.
if [[ -n $domain ]]; then
  sed -i 's/NETCONFIG_DNS_STATIC_SEARCHLIST=.*/NETCONFIG_DNS_STATIC_SEARCHLIST=\"'"${domain}"'\"/' /etc/sysconfig/network/config
fi
netconfig update -f

echo 'Dumping new settings for DNS:'
cat /etc/resolv.conf
grep NETCONFIG_DNS_STATIC_SERVERS /etc/sysconfig/network/config
grep NETCONFIG_DNS_STATIC_SEARCHLIST /etc/sysconfig/network/config
