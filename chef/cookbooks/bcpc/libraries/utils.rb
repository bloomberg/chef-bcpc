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
  nodes = if all
            search(:node, 'role:worknode')
          else
            search(:node, 'roles:worknode')
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

def os_adminrc # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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
  racks = node['bcpc']['networking']['topology']['racks']
  racks.map { |rack| "AZ-#{rack['id']}" }
end

def local_availability_zone
  match = node['hostname'].match(/.*r(\d+)(\w+)?n(\d+)$/i)
  raise "Unable to get availability zone for #{node['hostname']}" unless match
  "AZ-#{match.captures[0].to_i}"
end
