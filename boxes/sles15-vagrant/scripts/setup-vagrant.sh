#!/usr/bin/env bash

set -e

date > /etc/vagrant_box_build_time
# Create vagrant user
useradd -m -c "Vagrant" vagrant -s /bin/bash
echo "vagrant:vagrant" | chpasswd

# Installing vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
cd /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

# set vagrant sudo
printf "%b" "
# added by packer postinstall.sh
vagrant ALL=(ALL) NOPASSWD: ALL
" >> /etc/sudoers

# speed-up remote logins
printf "%b" "
# added by packer postinstall.sh
UseDNS no
" >> /etc/ssh/sshd_config

# disable gem docs
echo "gem: --no-ri --no-rdoc" >/etc/gemrc

# backlist i2c_piix4 - VirtualBox has no smbus
echo "blacklist i2c_piix4" > /etc/modprobe.d/100-blacklist-i2c_piix4.conf

# put shutdown command in path
ln -s /sbin/shutdown /usr/bin/shutdown

# ntp servers
printf "%b" "
# added by packer postinstall.sh
server 0.us.pool.ntp.org
server 1.us.pool.ntp.org
server 2.us.pool.ntp.org
server 3.us.pool.ntp.org
" >> /etc/ntp.conf

# Turn off swap
swapoff -a

# Cleanup vagrant
rm -rf /home/vagrant/*.sh
rm -rf /home/vagrant/.v*