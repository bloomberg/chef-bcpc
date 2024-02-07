# Cookbook:: bcpc
# Library:: zone_config
#
# Copyright:: 2023 Bloomberg Finance L.P.
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

require 'base64'

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

  def alternate_backends
    @node['bcpc']['cinder']['alternate_backends']['backends']
  end

  def alternate_backends_enabled?
    @node['bcpc']['cinder']['alternate_backends']['enabled']
  end

  def qos_default_limits
    @node['bcpc']['cinder']['qos_limits']
  end

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

      backend_to_add = {
        'name' => backend['name'],
        'private' => backend['private'],
        'client' => zone['ceph']['client'],
        'pool' => backend['pool']['name'],
        'libvirt_secret' => databag[zone['zone']]['libvirt']['secret'],
      }

      # Check if we have enabled qos for the specific storage backend
      # If so, combine the default qos limits along with any override values
      # and store them into this backend struct, so that they can be used
      # to create corresponding qos policy.
      backend_to_add['qos_enabled'] = @zone_config.node['bcpc']['cinder']['ceph']['qos_enabled']
      if backend_to_add['qos_enabled']
        backend_to_add['qos'] = get_combined_qos_limits(zone['cinder']['backend']['qos'])
      end

      backends.append(backend_to_add)
    end

    backends
  end

  def alternate_backends
    alternate_backends = []

    if !@zone_config.enabled? || !@zone_config.alternate_backends_enabled?
      return alternate_backends
    end

    zones = @zone_config.zone_attr()
    databag = @zone_config.databag(id: 'zones')
    general_backend_configs = Hash[
      @zone_config.alternate_backends()
                  .map { |backend| [backend[:name].to_s, backend] }]
    zones.each do |zone|
      next if zone['cinder']['alternate_backends'].nil?
      backends = zone['cinder']['alternate_backends']
      backend_databags = Hash[
      databag[zone['zone']]['alternate-backends']
                         .map { |b| [b[:name].to_s, b] }]
      backends.each do |backend|
        next unless general_backend_configs[backend['name']]['enabled']
        alternate_backend_to_add = {
          'backend_name' => backend['backend_name'],
          'volume_driver' => general_backend_configs[backend['name']]['volume_driver'],
          'properties' => {}.merge(
          general_backend_configs[backend['name']]['properties'])
                            .merge(Hash[backend_databags[backend['name']]['properties']
                            .map { |key, value| [key, Base64.decode64(value)] }])
                            .merge(backend['properties'] || {}),
          'private' => backend['private'],
          'volume_type_properties' => {}.merge(backend['volume_type_properties'])
                                        .map { |k, v| "--property #{k}=#{v}" }
                                        .join(' '),
        }

        # Check if we have enabled qos for the specific storage backend
        # If so, combine the default qos limits along with any override values
        # and store them into this alternate_backend struct, so that they can
        # be used to create corresponding qos policy.
        alternate_backend_to_add['qos_enabled'] = general_backend_configs[backend['name']]['qos_enabled']
        if alternate_backend_to_add['qos_enabled']
          alternate_backend_to_add['qos'] = get_combined_qos_limits(backend['qos'])
        end

        alternate_backends.append(alternate_backend_to_add)
      end
    end

    alternate_backends
  end

  # Combine default qos limits with override values
  def get_combined_qos_limits(overrides)
    overrides ? @zone_config.qos_default_limits.merge(overrides) : @zone_config.qos_default_limits
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
