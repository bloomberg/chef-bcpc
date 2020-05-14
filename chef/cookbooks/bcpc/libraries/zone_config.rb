# Cookbook:: bcpc
# Library:: zone_config
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

class ZoneConfig
  def initialize(node, region, data_bag_item)
    @cinder_config = CinderConfig.new(self)
    @data_bag_item = data_bag_item
    @node = node
    @nova_config = NovaConfig.new(self)
    @nova_compute_config = NovaComputeConfig.new(self)
    @region = region
  end

  attr_reader :cinder_config, :node, :nova_config, :nova_compute_config

  def databag(id:)
    @data_bag_item.call(@region, id)
  end

  def enabled?
    @node['bcpc']['zones']['enabled']
  end

  def zone
    node['zone']
  end

  def state_file
    '/usr/local/etc/bcc/zone'
  end

  def zone_attr(zone: nil)
    if zone.nil?
      return @node['bcpc']['zones']['partitions']
    end

    parts = @node['bcpc']['zones']['partitions']
    attr = parts.find { |p| p['zone'] == zone }
    raise "#{zone} not found" unless attr
    attr
  end
end

class CinderConfig
  def initialize(zone_config)
    @zone_config = zone_config
  end

  def backends
    backends = []

    unless @zone_config.enabled?
      config = @zone_config.databag(id: 'config')
      backends.append({
        'name' => 'ceph',
        'private' => false,
        'client' => @zone_config.node['bcpc']['cinder']['ceph']['user'],
        'pool' => @zone_config.node['bcpc']['cinder']['ceph']['pool']['name'],
        'libvirt_secret' => config['libvirt']['secret'],
      })
      return backends
    end

    zones = @zone_config.zone_attr()
    databag = @zone_config.databag(id: 'zones')
    zones.each do |zone|
      backend = zone['cinder']['backend']
      backends.append({
        'name' => backend['name'],
        'private' => backend['private'],
        'client' => zone['ceph']['client'],
        'pool' => backend['pool']['name'],
        'libvirt_secret' => databag[zone['zone']]['libvirt']['secret'],
      })
    end

    backends
  end

  def ceph_clients
    clients = []

    unless @zone_config.enabled?
      config = @zone_config.databag(id: 'config')
      client = @zone_config.node['bcpc']['cinder']['ceph']['user']
      nova_pools = @zone_config.nova_config.ceph_pools
      cinder_pools = self.ceph_pools
      pools = nova_pools + cinder_pools
      pools = pools.map { |p| p['pool'] }

      clients.append(
        {
          'client' => client,
          'key' => config['ceph']['client']['cinder']['key'],
          'pools' => pools,
        }
      )

      return clients
    end

    databag = @zone_config.databag(id: 'zones')
    zones = @zone_config.zone_attr()
    zones.each do |zone|
      zone_name = zone['zone']
      ceph_client = zone['ceph']['client']
      ceph_key = databag[zone_name]['ceph']['client'][ceph_client]['key']
      cinder_pool = self.ceph_pools.find { |p| p['zone'] == zone_name }
      nova_pools = @zone_config.nova_config.ceph_pools
      nova_pool = nova_pools.find { |p| p['zone'] == zone_name }
      pools = [cinder_pool['pool'], nova_pool['pool']]
      clients.append(
        {
          'client' => ceph_client,
          'key' => ceph_key,
          'pools' => pools,
        }
      )
    end

    clients
  end

  def ceph_pools
    pools = []

    unless @zone_config.enabled?
      pool = @zone_config.node['bcpc']['cinder']['ceph']['pool']['name']
      pools.append({ 'pool' => pool })
      return pools
    end

    zones = @zone_config.zone_attr()
    zones.each do |zone|
      pools.append({
        'zone' => zone['zone'],
        'pool' => zone['cinder']['backend']['pool']['name'],
      })
    end

    pools
  end

  def filters
    unless @zone_config.enabled?
      return []
    end
    %w(AvailabilityZoneFilter CapacityFilter CapabilitiesFilter AccessFilter)
  end
end

class NovaConfig
  def initialize(zone_config)
    @zone_config = zone_config
  end

  def ceph_pools
    pools = []

    unless @zone_config.enabled?
      pool = @zone_config.node['bcpc']['nova']['ceph']['pool']['name']
      pools.append({ 'pool' => pool })
      return pools
    end

    zones = @zone_config.zone_attr()
    zones.each do |zone|
      pools.append({
        'zone' => zone['zone'],
        'pool' => zone['nova']['ceph']['pool']['name'],
      })
    end

    pools
  end
end

class NovaComputeConfig
  def initialize(zone_config)
    @zone_config = zone_config
  end

  def ceph_user
    unless @zone_config.enabled?
      return @zone_config.node['bcpc']['cinder']['ceph']['user']
    end
    zone = @zone_config.zone_attr(zone: @zone_config.zone)
    zone['ceph']['client']
  end

  def ceph_pool
    unless @zone_config.enabled?
      return @zone_config.node['bcpc']['nova']['ceph']['pool']['name']
    end
    zone = @zone_config.zone_attr(zone: @zone_config.zone)
    zone['nova']['ceph']['pool']['name']
  end

  def ceph_key
    unless @zone_config.enabled?
      databag = @zone_config.databag(id: 'config')
      return databag['ceph']['client']['cinder']['key']
    end
    databag = @zone_config.databag(id: 'zones')
    zone = databag[@zone_config.zone]
    zone['ceph']['client'][self.ceph_user]['key']
  end

  def libvirt_secret
    unless @zone_config.enabled?
      databag = @zone_config.databag(id: 'config')
      return databag['libvirt']['secret']
    end
    databag = @zone_config.databag(id: 'zones')
    zone = databag[@zone_config.zone]
    zone['libvirt']['secret']
  end
end
