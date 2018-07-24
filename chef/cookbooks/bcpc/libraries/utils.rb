#
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
#

require 'ipaddress'

def is_queens?
  node['bcpc']['openstack']['release'] == 'queens'
end

def get_bootstrap_node()
  nodes = get_nodes("role:bootstrap")

  if nodes.size != 1
    raise 'There is not exactly one bootstrap node found.'
  end

  return nodes.first
end

def is_init_cloud()
  nodes = search(:node, "roles:headnode")
  nodes = nodes.reject{|n| n['hostname'] == node['hostname']}
  return nodes.length == 0 ? true : false
end

def is_headnode(node)
  return search(:node, "role:headnode AND hostname:#{node['hostname']}").any?
end

def is_worknode(node)
  return search(:node, "role:worknode AND hostname:#{node['hostname']}").any?
end

def get_headnodes(exclude: nil,all: false)

  nodes = []

  if exclude != nil
    nodes = search(:node, "roles:headnode")
    nodes = nodes.reject{|h| h['hostname'] == exclude}
  elsif all == true
    nodes = search(:node, "role:headnode")
  else
    nodes = search(:node, "roles:headnode")
  end

  return nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }

end

def get_worknodes(all: false)

  nodes = []

  if all == true
    nodes = search(:node, "role:worknode")
  else
    nodes = search(:node, "roles:worknode")
  end

  return nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }

end

def get_all_nodes()
  nodes = search(:node, "*:*")
  return nodes.sort! { |a, b| a['hostname'] <=> b['hostname'] }
end

def get_ceph_replica_count(pool)
  replicas = [get_ceph_osd_nodes.length, node['bcpc']['ceph'][pool]['replicas']].min
  replicas = 1 if replicas < 1
  return replicas
end

def get_ceph_optimal_pg_count(pool)
  power_of_2(
    get_ceph_osd_nodes.length *
    node['bcpc']['ceph']['pgs_per_node'] /
    node['bcpc']['ceph'][pool]['replicas'] *
    node['bcpc']['ceph'][pool]['portion'] / 100)
end


# Nearest power_of_2
def power_of_2(number)
#    result = 1
#    while (result < number) do result <<= 1 end
#    return result
  result = 1
  last_pwr = 1
  while result < number
    last_pwr = result
    result <<= 1
  end

  low_delta = number - last_pwr
  high_delta = result - number
  if high_delta > low_delta
    result = last_pwr
  end

  result
end


def calc_octets_to_drop(cidr)
  cidr = IPAddress(cidr)
  prefix = cidr.prefix.to_i
  prefix = 24 if prefix != 8 && prefix != 16
  4 - prefix / 8 # octets to drop
end

# Generates an array of classful reverse DNS zone(s) by dividing provided CIDR
# (min /24) in the form of '1.2.3.0/24'.
def calc_reverse_dns_zone(cidr)
  cidr = IPAddress(cidr)
  prefix = cidr.prefix.to_i
  prefix = 24 if prefix != 8 && prefix != 16
  subnets = cidr.subnet(prefix)
  octets = 4 - prefix / 8 # octets to drop
  subnets.map {
    |x| x.reverse.to_s.split('.')[octets, x.reverse.length].join('.') }
end

def generate_service_catalog_uri(svcprops, access_level)
  "https://#{node['bcpc']['cloud']['fqdn']}:#{svcprops['ports'][access_level]}/#{svcprops['uris'][access_level]}"
end

def mysqladmin()
  region = node['bcpc']['cloud']['region']
  config = data_bag_item(region,'config')
  return {
    "username" => "root",
    "password" => config['mysql']['users']['root']['password']
  }
end

def os_adminrc()
  region = node['bcpc']['cloud']['region']
  config = data_bag_item(region,'config')

  project   = node['bcpc']['openstack']['admin']['project']
  username  = node['bcpc']['openstack']['admin']['username']
  password  = config['openstack']['admin']['password']
  identity  = node['bcpc']['catalog']['identity']

  return {
    'OS_PROJECT_DOMAIN_ID' => 'default',
    'OS_USER_DOMAIN_ID' => 'default',
    'OS_PROJECT_NAME' => "#{project}",
    'OS_USERNAME' => "#{username}",
    'OS_PASSWORD' => "#{password}",
    'OS_AUTH_URL' => generate_service_catalog_uri(identity,'admin'),
    'OS_REGION_NAME' => "#{region}",
    'OS_IDENTITY_API_VERSION' => '3',
    'OS_VOLUME_API_VERSION'=> '3'
  }
end

def get_address(cidr)
  return IPAddress(cidr).address
end
