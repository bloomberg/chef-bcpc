#!/bin/bash

#
# This script expects to be run in the chef-bcpc directory
#

set -e
set -x

# Default to Test-Laptop if environmnet not passed in
ENVIRONMENT="${1-Test-Laptop}"

# We may need the proxy for apt-get later
if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

# needed within build_bins which we call
if [[ -z "$CURL" ]]; then
	echo "CURL is not defined"
	exit
fi

if [[ ! -f /etc/apt/sources.list.d/opscode.list ]]; then
  cp opscode.list /etc/apt/sources.list.d/
fi

# When rerunning a bootstrap, the 'apt-get update' gets very slow if
# the bootstrap node happens to be our apt mirror, so only do this if
# the package we're after is not installed at all
#
# See http://askubuntu.com/questions/44122/upgrade-a-single-package-with-apt-get
#
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

if dpkg -s chef-server 2>/dev/null | grep -q Status.*installed; then
  echo chef-server is installed
else
  DEBCONF_DB_FALLBACK=File{$(pwd)/debconf-chef.conf} DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install chef-server
fi


chmod +r /etc/chef/validation.pem
chmod +r /etc/chef/webui.pem

# copy our ssh-key to be authorized for root
if [[ -f $HOME/.ssh/authorized_keys && ! -f /root/.ssh/authorized_keys ]]; then
  if [[ ! -d /root/.ssh ]]; then
    mkdir /root/.ssh
  fi
  cp $HOME/.ssh/authorized_keys /root/.ssh/authorized_keys
fi

./build_bins.sh

if [[ ! -f /etc/apt/sources.list.d/bcpc.list ]]; then
  load_binary_server_info "$ENVIRONMENT"
  # Create an Apt repo entry
  echo "deb [arch=amd64] ${binary_server_url} 0.5.0 main" > /etc/apt/sources.list.d/bcpc.list
  # add repo key
  apt-key add bins/apt_key.pub
  # ensure we do not have a proxy set for the local repo
  proxy_line="Acquire::http::Proxy::${binary_server_host} 'DIRECT';"
  grep -q "$proxy_line" /etc/apt/apt.conf || echo "$proxy_line" >> /etc/apt/apt.conf
  # update only the BCPC local repo
  apt-get -o Dir::Etc::SourceList=/etc/apt/sources.list.d/bcpc.list,Dir::Etc::SourceParts= update
fi

