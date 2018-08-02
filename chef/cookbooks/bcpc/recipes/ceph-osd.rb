# Cookbook Name:: bcpc
# Recipe:: ceph-osd

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

include_recipe 'bcpc::ceph-packages'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

template '/etc/ceph/ceph.conf' do
  source 'ceph/ceph.conf.erb'

  networks = cloud_networks
  primary = networks['primary']
  storage = networks['storage']

  variables(
    config: config,
    public_network: primary['cidr'],
    cluster_network: storage['cidr'],
    headnodes: init_cloud? ? [node] : headnodes
  )
end

template '/etc/ceph/ceph.bootstrap-osd.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-osd',
    client: config['ceph']['bootstrap']['osd'],
    caps: ['caps mon = "allow profile bootstrap-osd"']
  )
end

template '/etc/ceph/ceph.client.admin.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'admin',
    client: config['ceph']['client']['admin'],
    caps: [
      'caps mds = "allow *"',
      'caps mgr = "allow *"',
      'caps mon = "allow *"',
      'caps osd = "allow *"',
    ]
  )
end

begin
  rack = local_ceph_rack
  host = node['hostname']

  node['bcpc']['ceph']['osds'].each do |osd|
    bash "ceph-deploy osd create #{osd}" do
      cwd '/etc/ceph'
      code <<-EOH
        ceph-deploy osd create #{host}:#{osd}; sleep 5
      EOH
      only_if "lsblk /dev/#{osd}"
      not_if "blkid /dev/#{osd}1 | grep 'ceph data'"
    end
  end

  bash "move #{host} host to ceph rack bucket" do
    code <<-EOH
      ceph osd crush move #{host} rack=#{rack}
    EOH
  end
end
