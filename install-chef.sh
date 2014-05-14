#!/bin/bash

# if you dont have internet access from your cluster nodes, you will
# not be able to "knife bootstrap" nodes to get them ready for
# chef. Instead you need to install chef separately. Assuming the
# necessary bits are on apt/apache mirror as per the mirror
# instructions in bootstrap.md then the following will get chef
# installed and allow you to proceed

# change the following IP address to match your bootstrap node

if dpkg -s opscode-keyring 2>/dev/null | grep -q Status.*installed; then
  echo opscode-keyring is installed
else 
  apt-get update
  apt-get --allow-unauthenticated -y install opscode-keyring
  apt-get update
fi

if dpkg -s chef 2>/dev/null | grep -q Status.*installed; then
  echo chef is installed
else
  DEBCONF_DB_FALLBACK=File{$(pwd)/debconf-chef.conf} DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install chef
fi
