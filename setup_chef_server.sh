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

if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

if [[ ! -f /etc/apt/sources.list.d/bcpc.list ]]; then
  load_binary_server_info "$ENVIRONMENT"

  # create an Apt repo entry
  echo "deb ${binary_server_url} /" > /etc/apt/sources.list.d/bcpc.list

  # add repo key
  apt-key add bins/apt_key.pub

  # ensure we do not have a proxy set for the local repo
  proxy_line="Acquire::http::Proxy::${binary_server_host} 'DIRECT';"
  grep -q "$proxy_line" /etc/apt/apt.conf || \
    echo "$proxy_line" >> /etc/apt/apt.conf

  # update only the BCPC local repo
  apt-get -o Dir::Etc::SourceList=/etc/apt/sources.list.d/bcpc.list,Dir::Etc::SourceParts= update
fi 

if dpkg -s chef 2>/dev/null | grep -q ^Status.*installed && \
   dpkg -s chef 2>/dev/null | grep -q ^Version.*11; then
  echo chef is installed
else
  apt-get -y install chef
fi

if dpkg -s chef-server 2>/dev/null | grep -q ^Status.*installed && \
   dpkg -s chef 2>/dev/null | grep -q ^Version.*11; then
  echo chef-server is installed
else
  apt-get -y install chef-server
  mkdir /etc/chef-server
  echo "nginx['enable_non_ssl'] = false" > /etc/chef-server/chef-server.rb
  echo "nginx['non_ssl_port'] = 4000" >> /etc/chef-server/chef-server.rb
  chef-server-ctl reconfigure
fi

# copy our ssh-key to be authorized for root
if [[ -f $HOME/.ssh/authorized_keys && ! -f /root/.ssh/authorized_keys ]]; then
  if [[ ! -d /root/.ssh ]]; then
    mkdir /root/.ssh
  fi
  cp $HOME/.ssh/authorized_keys /root/.ssh/authorized_keys
fi
