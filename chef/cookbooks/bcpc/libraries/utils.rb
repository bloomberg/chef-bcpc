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

def headnode?
  search(:node, "role:headnode AND hostname:#{node['hostname']}").any?
end

def worknode?
  search(:node, "role:worknode AND hostname:#{node['hostname']}").any?
end

def bootstraps
  nodes = search(:node, 'role:bootstrap')
  nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def headnodes(exclude: nil, all: false)
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

def worknodes(all: false)
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

def cloud_racks(rack_id: nil)
  racks = node['bcpc']['networking']['racks']

  return racks if rack_id.nil?

  rack = racks.select do |r|
    r['id'] == rack_id
  end

  raise "could not find rack #{rack_id}" if rack.nil?

  return rack
end

def node_pod
  node_map = node_network_map
  rack = cloud_racks(rack_id: node_map['rack_id'])
  pod_id = node_map['pod_id']

  pod = rack.find do |p|
    p['pod'] == node_map['pod_id']
  end

  raise "could not find pod #{pod_id}" if pod.nil?

  return pod
end

def node_interfaces(type: nil)
  interfaces = [node_primary_interface, node_storage_interface]
  return interfaces if type.nil?

  iface = node_interfaces.find { |i| i['type'] == type }
  raise "could not find interface #{type}" if iface.nil?

  return iface
end

def cloud_networks(network: nil)
  networks = node['bcpc']['networking']['networks']
  return networks if network.nil?
  raise "#{network} not found" unless networks.key?(network)
  return networks[network]
end

def node_primary_interface
  interface = node_interface(
    type: 'primary',
    ip_address: node['ipaddress']
  )

  return interface
end

def node_storage_interface
  type = 'storage'
  pod = node_pod
  pod_network = pod['networks'][type]
  cloud_network = cloud_networks(network: type)

  interface = node_interface(
    type: type,
    ip_address: generate_ip_address(
      'source_ip': node['ipaddress'],
      'network_cidr': pod_network['cidr']
    )
  )

  # add route to storage network
  interface['route'] = {
    'to' => cloud_network['cidr'],
    'via' => pod_network['gateway']
  }

  return interface
end

def node_interface(type: nil, ip_address: nil)
  pod = node_pod
  pod_network = pod['networks'][type]
  cloud_network = cloud_networks(network: type)

  interface = {
    'type' => type,
    'ip' => ip_address,
    'prefix' => IPAddress(pod_network['cidr']).prefix.to_i,
    'gw' => pod_network['gateway'],
    'dev' => cloud_network['interface']
  }

  interface['vlan'] = cloud_network['vlan'] if cloud_network.key?('vlan')
  interface['mtu'] = cloud_network['mtu'] if cloud_network.key?('mtu')

  return interface
end

def generate_ip_address(source_ip:, network_cidr:)
  # generate ip address by using the source ip and applying
  # the same ip host id to the desired network cidr
  prefix = IPAddress(network_cidr).prefix.to_i
  host_id = (IPAddr.new(source_ip) << prefix >> prefix).to_i
  host_network = IPAddr.new(network_cidr)
  host_network = host_network >> (32 - prefix) << (32 - prefix)

  return (host_network | host_id).to_s
end
