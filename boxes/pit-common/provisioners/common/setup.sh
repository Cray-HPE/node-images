#!/bin/bash

set -e

GOSS_BASE=/opt/cray/tests/install/livecd

echo "Initializing log location(s)"
mkdir -p /var/log/cray
cat << 'EOF' > /etc/logrotate.d/cray
/var/log/cray/*.log {
  size 1M
  create 744 root root
  rotate 4
}
EOF

echo "Modifying DNS to use Cray DNS servers..."
cp /etc/sysconfig/network/config /etc/sysconfig/network/config.backup
sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*$|NETCONFIG_DNS_STATIC_SERVERS="172.31.84.40 172.30.84.40"|g' /etc/sysconfig/network/config
systemctl restart network

echo "Initializing directories and resources"
mkdir -p /srv/cray
cp -r /tmp/files/* /srv/cray/
chmod +x -R /srv/cray/scripts
rm -rf /tmp/files
cp /srv/cray/sysctl/common/* /etc/sysctl.d/
cp /srv/cray/limits/98-cray-limits.conf /etc/security/limits.d/98-cray-limits.conf

# TODO: default root ssh key details should be parameterized. These keys should ALWAYS
# be overridden at install/upgrade time based on customer configuration, and thus these
# built-in ones should really only be relevant for any needed build-time needs. Nonetheless,
# this should still not be hard-coded, it was just originally translated from previous build
# scripts to reduce impact during transitional periods
echo "Setting up default, initial root SSH configuration/credentials"
mkdir -p /root/.ssh
cat > /root/.ssh/id_rsa << EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEArq+xyoMdc32q0rhB0DErNl8xK8AyXN1jfK0p89PsN/UCc9OC
raRZ8xftD9uTgrQsGQBsInIJcxUlIApGfit+eQZBhycCSfW3IBt2g3JdGwFMGrT4
llfC7pTLQS4IgHl9WmyKGRoiYlDdyAHWzSIcKYeyY6DFIM0zNV0FW7LwpbrtzxU8
dh2vNjUBsojQjdY9YFgWytlOHz60s4k3yWMuXpRH2uLrv4ka3pr22Q+NTG+lMWAw
Ukxo2Uhb/sdeAFroFxGjIuZxQBXjkLSWpPmAgoYMa72mJYiTJpHhXcGEnFaNbZz4
ipgLtxdnMEaPymQkeGcUpIso8BJIt+AJp9uVkQIDAQABAoIBAH8BrNFhjOsoRifY
4bjd1t48TcLShYtxR2EhgawOu+NfVv4hnRRktyWAktKBwfk4yAsRfI16vhYXHJvz
/JbFRrn1a3U5Tne5mABXF06wurLkuZF9XHPqsQbH1hO4xWOrcRFqcumXT8KNqwI9
HBCfKTyktXWsMUcNCptU2411R3Qmhil5wdgJQNrEl1qMiLOBeTrE5gEBh9nylIoC
UW5tejBUX+9/LTFmyYb249Mb32aNPDDxe76PFTeNUvqYmh8xv1KbdD2sCIYWxmk+
snUujljMxAETylepItFF0DOQsVwS8posvwRAgxsqKTDNaGma92Tbh33fSgNwjBDW
zNO7y6UCgYEA17o8eUZucy0ifh4Kvmey7etT5Jvig9EtL8ZK4byCspd//FO0Q081
FwK0YycYlP8YSO+mIAefU2YZC8qRPNqxW5/TmrvdObsXfy9TbmbnjXmcsQVdwHxv
jHnoNgmOLqQdQGbqQ+jg2CPHSp+DjmdiQQ60lotny5moOs1YPTnT5C8CgYEAz0wS
hDLi1XCULni7lKez/xj2EpfMDqRh9JwPAEA7+HYKf9Np7M1hz/X3ZlWKiXZxmgT5
l1fRhwjTVMgneBfkmg0ePmxq+zzwnTC8OCbE3DMCw+SRXE6cCOxjsDXpBwqtWIn+
B1k8c4cI+ebKUP+IAUvdDXbkPKbow9CbuNae8j8CgYAdKGToF2byVlVlKnZVSfrb
QYVzTsaM/obXADw6ypn3vZZk6oNg3aHVXF45UJ139gq4QPv5NE6KnTAhcd2zlfOG
6NFXBrFeDjWc0S67q1j8vEU7f/gt/iOtnwSN2TjIgRIbFE3xo9ZQIHXdVjYX101m
cbBi8LC0yi381KhqjhhfrQKBgE5/Xw+ieVUb0XEblOTA8J8r45q80q/Evbc0FVYh
/NOkV2t6MkVSrLRkTu/4eoJ9UJ1jPuR5g8VfqS8UsCWA3rcbOpWm1ogW1oKfvtaA
j9FWm7h0aDsNJXcXlNRYRcq911CMyJ4dw4931gVTyM8NRIJBKQ79M4ZoKgJkj2Na
GkxfAoGASe0i9N3Auk7opsDK+CgyujVuR2YF3hpro1fiW8Z8UWbseOPBnMTUVWZa
gsXsdmcoFiHp3IcJ2aqjwrbTGnIduU00vn6IGBRTxI2upCIrawQN24Jqjgw/PJ17
lp3iQ80542iRxFeV/XQTpUzR5dUWLOrD1kHtq28nmNcS6ZivWfE=
-----END RSA PRIVATE KEY-----
EOF
cat > /root/.ssh/id_rsa.pub << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCur7HKgx1zfarSuEHQMSs2XzErwDJc3WN8rSnz0+w39QJz04KtpFnzF+0P25OCtCwZAGwicglzFSUgCkZ+K355BkGHJwJJ9bcgG3aDcl0bAUwatPiWV8LulMtBLgiAeX1abIoZGiJiUN3IAdbNIhwph7JjoMUgzTM1XQVbsvCluu3PFTx2Ha82NQGyiNCN1j1gWBbK2U4fPrSziTfJYy5elEfa4uu/iRremvbZD41Mb6UxYDBSTGjZSFv+x14AWugXEaMi5nFAFeOQtJak+YCChgxrvaYliJMmkeFdwYScVo1tnPiKmAu3F2cwRo/KZCR4ZxSkiyjwEki34Amn25WR
EOF
cat > /root/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCur7HKgx1zfarSuEHQMSs2XzErwDJc3WN8rSnz0+w39QJz04KtpFnzF+0P25OCtCwZAGwicglzFSUgCkZ+K355BkGHJwJJ9bcgG3aDcl0bAUwatPiWV8LulMtBLgiAeX1abIoZGiJiUN3IAdbNIhwph7JjoMUgzTM1XQVbsvCluu3PFTx2Ha82NQGyiNCN1j1gWBbK2U4fPrSziTfJYy5elEfa4uu/iRremvbZD41Mb6UxYDBSTGjZSFv+x14AWugXEaMi5nFAFeOQtJak+YCChgxrvaYliJMmkeFdwYScVo1tnPiKmAu3F2cwRo/KZCR4ZxSkiyjwEki34Amn25WR
EOF
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub
chmod 644 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown -R root:root /root

# Change hostname from lower layer to ncn.
echo 'pit' > /etc/hostname

# Lock the kernel before we move onto installing anything []for NCNs
uname -r
rpm -qa kernel-default
zypper addlock kernel-default

# Install jq
command -v jq >/dev/null 2>&1 || zypper -n install --auto-agree-with-licenses jq=1.6-3.3.1
