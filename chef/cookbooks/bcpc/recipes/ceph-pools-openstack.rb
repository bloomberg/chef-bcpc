# Cookbook:: bcpc
# Recipe:: ceph-pools-openstack
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
zone_config = ZoneConfig.new(node, region, method(:data_bag_item))
nova_config = zone_config.nova_config
cinder_config = zone_config.cinder_config
num_storagenodes = search(:node, 'roles:storagenode').length

# create Ceph RBD pool for Glance
bash 'create ceph pool' do
  pool = node['bcpc']['glance']['ceph']['pool']['name']
  pg_num = node['bcpc']['ceph']['pg_num']
  pgp_num = node['bcpc']['ceph']['pgp_num']

  code <<-DOC
    ceph osd pool create #{pool} #{pg_num} #{pgp_num}
    ceph osd pool application enable #{pool} rbd
  DOC

  not_if "ceph osd pool ls | grep -w #{pool}"
end

if num_storagenodes > 0
  execute 'set ceph pool size' do
    size = ceph_pool_size(node['bcpc']['glance']['ceph']['pool']['size'])
    pool = node['bcpc']['glance']['ceph']['pool']['name']

    command "ceph osd pool set #{pool} size #{size} --yes-i-really-mean-it"
    not_if "ceph osd pool get #{pool} size | grep -w 'size: #{size}'"
  end
end

# If this node is an OpenStack headnode and a storage headnode, then the
# Glance recipe is responsible for creating the client.glance Ceph user
# and keyring.
unless headnode?
  template '/etc/ceph/ceph.client.glance.keyring' do
    source 'glance/ceph.client.glance.keyring.erb'

    mode '0640'
    owner 'root'

    variables(
      key: config['ceph']['client']['glance']['key']
    )
    notifies :run, 'execute[import glance ceph client key]', :immediately
  end

  execute 'import glance ceph client key' do
    action :nothing
    command 'ceph auth import -i /etc/ceph/ceph.client.glance.keyring'
  end
end

# create Ceph RBD pools for Nova
nova_config.ceph_pools.each do |pool|
  pool_name = pool['pool']
  pg_num = node['bcpc']['ceph']['pg_num']
  pgp_num = node['bcpc']['ceph']['pgp_num']

  bash "create the #{pool_name} ceph pool" do
    code <<-DOC
      ceph osd pool create #{pool_name} #{pg_num} #{pgp_num}
      ceph osd pool application enable #{pool_name} rbd
    DOC

    not_if "ceph osd pool ls | grep -w ^#{pool_name}$"
  end

  next if num_storagenodes == 0

  execute 'set ceph pool size' do
    size = ceph_pool_size(node['bcpc']['nova']['ceph']['pool']['size'])
    command "ceph osd pool set #{pool_name} size #{size} --yes-i-really-mean-it"
    not_if "ceph osd pool get #{pool_name} size | grep -w 'size: #{size}'"
  end
end

# create Ceph RBD pools for Cinder
cinder_config.ceph_pools.each do |pool|
  pool_name = pool['pool']
  bash "create the #{pool_name} ceph pool" do
    pg_num = node['bcpc']['ceph']['pg_num']
    pgp_num = node['bcpc']['ceph']['pgp_num']

    code <<-DOC
      ceph osd pool create #{pool_name} #{pg_num} #{pgp_num}
      ceph osd pool application enable #{pool_name} rbd
    DOC

    not_if "ceph osd pool ls | grep -w ^#{pool_name}$"
  end

  next if num_storagenodes == 0
  execute 'set ceph pool size' do
    size = ceph_pool_size(node['bcpc']['cinder']['ceph']['pool']['size'])
    command "ceph osd pool set #{pool_name} size #{size} --yes-i-really-mean-it"
    not_if "ceph osd pool get #{pool_name} size | grep -w 'size: #{size}'"
  end
end

# If this node is an OpenStack headnode and a storage headnode, then the
# Cinder recipe is responsible for creating the client.*cinder Ceph users
# and keyrings.
unless headnode?
  cinder_config.ceph_clients.each do |client|
    template "/etc/ceph/ceph.client.#{client['client']}.keyring" do
      source 'cinder/ceph.client.cinder.keyring.erb'

      mode '0640'
      owner 'root'

      variables(
        client: client['client'],
        key: client['key'],
        pools: client['pools']
      )
    end

    execute 'import cinder ceph client key' do
      command \
        "ceph auth import -i /etc/ceph/ceph.client.#{client['client']}.keyring"
    end
  end
end
