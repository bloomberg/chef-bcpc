# Cookbook Name:: bcpc
# Library:: utils
#
# Copyright 2018, Bloomberg Finance L.P.
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

return Chef::Log.warn('requires chef-server') if Chef::Config[:solo]

require 'ipaddr'
require 'ipaddress'

def init_cloud?
  nodes = search(:node, 'roles:headnode')
  nodes = nodes.reject { |n| n['hostname'] == node['hostname'] }
  nodes.empty? ? true : false
end

def headnode?(node)
  search(:node, "role:headnode AND hostname:#{node['hostname']}").any?
end

def worknode?(node)
  search(:node, "role:worknode AND hostname:#{node['hostname']}").any?
end

def bootstraps
  nodes = search(:node, 'role:bootstrap')
  nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_headnodes(exclude: nil, all: false)
  nodes = []

  if !exclude.nil?
    nodes = search(:node, 'roles:headnode')
    nodes = nodes.reject { |h| h['hostname'] == exclude }
  elsif all == true
    nodes = search(:node, 'role:headnode')
  else
    nodes = search(:node, 'roles:headnode')
  end

  nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_worknodes(all: false)
  nodes = []

  if all
    nodes = search(:node, 'role:worknode')
  else
    nodes = search(:node, 'roles:worknode')
  end

  nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def all_nodes
  nodes = search(:node, '*:*')
  nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def generate_service_catalog_uri(svcprops, access_level)
  fqdn = node['bcpc']['cloud']['fqdn']
  port = svcprops['ports'][access_level]
  path = svcprops['uris'][access_level]
  "https://#{fqdn}:#{port}/#{path}"
end

def mysqladmin
  region = node['bcpc']['cloud']['region']
  config = data_bag_item(region, 'config')
  {
    'username' => 'root',
    'password' => config['mysql']['users']['root']['password']
  }
end

def os_adminrc
  region = node['bcpc']['cloud']['region']
  config = data_bag_item(region, 'config')

  identity = node['bcpc']['catalog']['identity']

  {
    'OS_PROJECT_DOMAIN_ID' => 'default',
    'OS_USER_DOMAIN_ID' => 'default',
    'OS_PROJECT_NAME' => node['bcpc']['openstack']['admin']['project'],
    'OS_USERNAME' => node['bcpc']['openstack']['admin']['username'],
    'OS_PASSWORD' => config['openstack']['admin']['password'],
    'OS_AUTH_URL' => generate_service_catalog_uri(identity, 'admin'),
    'OS_REGION_NAME' => region,
    'OS_IDENTITY_API_VERSION' => '3',
    'OS_VOLUME_API_VERSION' => '3'
  }
end

def get_address(cidr)
  IPAddress(cidr).address
end

def availability_zones
  racks = node['bcpc']['networking']['racks']
  racks.map { |rack| "AZ-#{rack['id']}" }
end

def local_availability_zone
  node_map = node_network_map
  "AZ-#{node_map['rack_id']}"
end

def node_network_map
  # try to get node information via the node hostname
  match = node['hostname'].match(/^.*r(\d+)(\w+)?n(\d+).*$/i)
  raise 'could not determine node information from hostname' if match.nil?

  {
    'rack_id' => match.captures[0].to_i,
    'pod_id' => match.captures[1],
    'node_id' => match.captures[2]
  }
end

def node_networking
  {
    'rack' => node_rack,
    'interfaces' => node_interfaces
  }
end

def node_rack
  node_map = node_network_map
  racks = node['bcpc']['networking']['racks']

  racks.find do |r|
    r['id'] == node_map['rack_id'] && r['pod'] == node_map['pod_id']
  end
end

def node_interfaces
  [node_primary_interface, node_storage_interface]
end

def node_primary_interface
  rack = node_rack
  rack_network = rack['networks']['primary']
  cloud_network = node['bcpc']['networking']['networks']['primary']
  prefix = IPAddress(rack_network['cidr']).prefix.to_i
  gateway = rack_network['gateway']
  primary_ip = node['ipaddress']

  iface = {
    'type' => 'primary',
    'ip' => primary_ip,
    'prefix' => prefix,
    'gw' => gateway,
    'dev' => cloud_network['interface']
  }

  iface['vlan'] = cloud_network['vlan'] if cloud_network.key?('vlan')
  iface['mtu'] = cloud_network['mtu'] if cloud_network.key?('mtu')

  return iface
end

def node_storage_interface
  rack = node_rack
  primary_ip = node['ipaddress']
  rack_network = rack['networks']['storage']
  cloud_network = node['bcpc']['networking']['networks']['storage']
  prefix = IPAddress(rack_network['cidr']).prefix.to_i
  host_id = (IPAddr.new(primary_ip) << prefix >> prefix).to_i
  host_network = IPAddr.new(rack_network['cidr'])
  host_network = host_network >> (32 - prefix) << (32 - prefix)
  storage_ip = (host_network | host_id).to_s

  iface = {
    'type' => 'storage',
    'ip' => storage_ip,
    'prefix' => prefix,
    'route' => {
      'to' => rack_network['cidr'],
      'via' => rack_network['gateway']
    },
    'dev' => cloud_network['interface']
  }

  iface['vlan'] = cloud_network['vlan'] if cloud_network.key?('vlan')
  iface['mtu'] = cloud_network['mtu'] if cloud_network.key?('mtu')

  return iface
end
