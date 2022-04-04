#!/bin/bash
set -x
# rsyslog config to ensure the NCN OS logs are routed to SMF
cat << EOF > /etc/rsyslog.d/01-cray-rsyslog.conf
*.* action(
  type="omfwd"    target="rsyslog-aggregator.nmnlb"
  port="514"
  protocol="tcp"
  template="RSYSLOG_SyslogProtocol23Format"
)
EOF
chmod 600 /etc/rsyslog.d/01-cray-rsyslog.conf
