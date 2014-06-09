#!/bin/bash

# delete all linux headers
dpkg --list | awk '{print $2}' | grep linux-headers | xargs apt-get -y purge

# does anyone use ppp anymore?
apt-get -y purge ppp pppconfig pppoeconf

# delete anonymous reporting of statistics
apt-get -y purge popularity-contest

# general clean-up and removal
apt-get -y autoremove
apt-get -y clean

# remove file provisioned files
rm id_rsa.pub

# remove Packer uploaded files
rm VBoxGuestAdditions-*.iso
rm .vbox_version

