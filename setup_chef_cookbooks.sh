#!/bin/bash -e

# Expected to be run in the root of the Chef Git repository (e.g. chef-bcpc)

set -x

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

BOOTSTRAP_IP="${1-10.0.100.3}"
USER="${2-root}"
ENVIRONMENT="${3-Test-Laptop}"

# load binary_server_url and binary_server_host (usually the bootstrap)
load_binary_server_info "$ENVIRONMENT"

# make sure we do not have a previous .chef directory in place to allow re-runs
if [[ -f .chef/knife.rb ]]; then
  sudo knife node delete `hostname -f` -y -k /etc/chef-server/admin.pem -u admin || true
  sudo knife client delete `hostname -f` -y -k /etc/chef-server/admin.pem -u admin || true
  mv .chef/ ".chef_found_$(date +"%m-%d-%Y %H:%M:%S")"
fi

mkdir .chef
cat << EOF > .chef/knife.rb
require 'rubygems'
require 'ohai'
o = Ohai::System.new
o.all_plugins
 
log_level                :info
log_location             STDOUT
node_name                o[:fqdn]
client_key               "$(pwd)/.chef/#{o[:fqdn]}.pem"
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          'https://${BOOTSTRAP_IP}'
syntax_check_cache_path  '$(pwd)/.chef/syntax_check_cache'
cookbook_path '$(pwd)/cookbooks'
 
# Disable the Ohai password module which explodes on a Single-Sign-On-joined system
Ohai::Config[:disabled_plugins] = [ "passwd" ]
no_proxy_array = ["localhost", o[:ipaddress], o[:hostname], o[:fqdn], "${BOOTSTRAP_IP}", "${binary_server_host}"]
no_proxy_array.insert("*#{o[:domain]}") unless o[:domain].nil?
no_proxy_string = no_proxy_array.uniq * ","

ENV['http_proxy'] = "${http_proxy}"
ENV['https_proxy'] = "${https_proxy}"
ENV['no_proxy'] = no_proxy_string
http_proxy ENV['http_proxy']
https_proxy ENV['https_proxy']
no_proxy no_proxy_string
EOF
cd cookbooks

# allow versions on cookbooks via "cookbook version"
for cookbook in apt python build-essential ubuntu cron "chef-client 3.0.6" ntp "yum 2.4.2" logrotate; do
  if [[ ! -d ${cookbook% *} ]]; then
     # unless the proxy was defined this knife config will be the same as the one generated above
    knife cookbook site download $cookbook --config ../.chef/knife.rb
    tar zxf ${cookbook% *}*.tar.gz
    rm ${cookbook% *}*.tar.gz
  fi
done
[[ -d dpkg_autostart ]] || git clone https://github.com/hw-cookbooks/dpkg_autostart.git
