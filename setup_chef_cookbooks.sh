#!/bin/bash -e

# Expected to be run in the root of the Chef Git repository (e.g. chef-bcpc)

set -x

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

if [[ -z "$1" ]]; then
	BOOTSTRAP_IP=10.0.100.3
else
	BOOTSTRAP_IP=$1
fi

if [[ -z "$2" ]]; then
	USER=root
else
	USER=$2
fi

# make sure we do not have a previous .chef directory in place to allow re-runs
if [[ -f .chef/knife.rb ]]; then
  knife node delete `hostname -f` -y || true
  knife client delete $USER -y || true
  mv .chef/ ".chef_found_$(date +"%m-%d-%Y %H:%M:%S")"
fi
echo -e ".chef/knife.rb\nhttp://$BOOTSTRAP_IP:4000\n\n\n/etc/chef-server/chef-webui.pem\n\n/etc/chef-server/chef-validator.pem\n.\n" | knife configure --initial

cp -p .chef/knife.rb .chef/knife-proxy.rb

if [[ ! -z "$http_proxy" ]]; then
  echo  "http_proxy  \"${http_proxy}\"" >> .chef/knife-proxy.rb
  echo "https_proxy \"${https_proxy}\"" >> .chef/knife-proxy.rb
fi

cd cookbooks

# allow versions on cookbooks so 
for cookbook in "apt 1.10.0" ubuntu cron "chef-client 3.3.8" chef-solo-search ntp "yum 3.2.2" "logrotate 1.6.0"; do
  if [[ ! -d ${cookbook% *} ]]; then
     # unless the proxy was defined this knife config will be the same as the one generated above
    knife cookbook site download $cookbook --config ../.chef/knife-proxy.rb
    tar zxf ${cookbook% *}*.tar.gz
    rm ${cookbook% *}*.tar.gz
    if [[ -f ${cookbook% *}.patch ]]; then
      pushd ${cookbook% *}
      patch -p1 < ../${cookbook% *}.patch
      popd
    fi
  fi
done
