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

node.set['bcpc']['management']['ip'] = node['network']['interfaces'][node['bcpc']['management']['interface']]['addresses'].select { |k, v| v['family'] == "inet" and k != node['bcpc']['management']['vip'] }.first[0]

# Compute the bitlen for each of the network cidrs
mgmt_bitlen = (node['bcpc']['management']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
stor_bitlen = (node['bcpc']['storage']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i
flot_bitlen = (node['bcpc']['floating']['cidr'].match /\d+\.\d+\.\d+\.\d+\/(\d+)/)[1].to_i

# Save the host number on the mgmt network to the node_number for this node
mgmt_hostaddr = IPAddr.new(node['bcpc']['management']['ip'])<<mgmt_bitlen>>mgmt_bitlen
node.set['bcpc']['node_number'] = mgmt_hostaddr.to_i.to_s

# Keep the same host number for addresses on the storage and float networks
node.set['bcpc']['storage']['ip'] = ((IPAddr.new(node['bcpc']['storage']['cidr'])>>(32-stor_bitlen)<<(32-stor_bitlen))|mgmt_hostaddr).to_s
node.set['bcpc']['floating']['ip'] = ((IPAddr.new(node['bcpc']['floating']['cidr'])>>(32-flot_bitlen)<<(32-flot_bitlen))|mgmt_hostaddr).to_s

# Take a guess at the rack name or default to 'rack'
if node['bcpc']['rack_name'].nil? then
    rack_guess = node['hostname'].match /.*-r(\d+)[a-d]?n\d+$/
    node.set['bcpc']['rack_name'] = (rack_guess.nil?) ? "rack" : "rack-#{rack_guess[1].to_i}"
end

node.save rescue nil
