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

node.set['bcpc']['management']['ip'] = node['network']['interfaces'][node['bcpc']['management']['interface']]['addresses'].select {|k,v| v['family'] == "inet" and k != node['bcpc']['management']['vip'] }[0].first

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
