#
# Cookbook Name:: bcpc
# Recipe:: default
#
# Copyright 2013, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'ipaddr'

mgmt_cidr = IPAddr.new(node['bcpc']['management']['cidr'])

ifs=node[:network][:interfaces].keys
# create a hash of ipaddresses
ips= ifs.map{|a|node[:network][:interfaces][a][:addresses]}.reduce({}, :merge)

# select the first IP address which is on the management network
node.set['bcpc']['management']['ip'] = ips.select {|ip,v| v['family'] == "inet" and
                                                   ip != node['bcpc']['management']['vip'] and
                                                   mgmt_cidr===ip}.first[0]

mgmt_bitlen = (node['bcpc']['management']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
mgmt_hostaddr = IPAddr.new(node['bcpc']['management']['ip'])<<mgmt_bitlen>>mgmt_bitlen

stor_bitlen = (node['bcpc']['storage']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
stor_hostaddr = IPAddr.new(node['bcpc']['management']['ip'])<<stor_bitlen>>stor_bitlen

flot_bitlen = (node['bcpc']['floating']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
##If we have a full class B, then simply leave the 3rd octet alone and use the 4th octet from mgmt ip
#Then we leave the rest of the float Ips for the VMs
flot_bitlen = 24 if flot_bitlen == 16
flot_hostaddr = IPAddr.new(node['bcpc']['management']['ip'])<<flot_bitlen>>flot_bitlen

node.set['bcpc']['node_number'] = mgmt_hostaddr.to_i.to_s
node.set['bcpc']['storage']['ip'] = ((IPAddr.new(node['bcpc']['storage']['cidr'])>>(32-stor_bitlen)<<(32-stor_bitlen))|stor_hostaddr).to_s
node.set['bcpc']['floating']['ip'] = ((IPAddr.new(node['bcpc']['floating']['cidr'])>>(32-flot_bitlen)<<(32-flot_bitlen))|flot_hostaddr).to_s

node.save rescue nil

# ensure the Zookeeper Gem is available for use in later recipes
# it seems chef_gem fails to use the embedded gem(1) binary so use gem_package
# and a hack to use rubygems to find the current Ruby binary;
# assume gem is in the same dir (valid for Chef 10, Chef 11 dpkg and Chef 11 Omnibus)
require 'pathname'
require 'rubygems'
gem_path = Pathname.new(Gem.ruby).dirname.join("gem").to_s

# build requirements for zookeeper
%w{make patch gcc}.each do |pkg|
  package pkg do
    action :nothing
  end.run_action(:install)
end

gem_package "zookeeper" do
    gem_binary gem_path
    options "--no-http-proxy --clear-sources --source #{get_binary_server_url}"
    # workaround for CHEF-3912 is to include versions from build_bins.sh
    version "1.4.7"
    action :nothing
end.run_action(:install)

Gem.clear_paths
require 'zookeeper'
