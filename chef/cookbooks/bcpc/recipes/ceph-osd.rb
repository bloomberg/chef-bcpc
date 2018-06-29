#
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
#
include_recipe 'bcpc::ceph-packages'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region,'config')

template '/etc/ceph/ceph.conf' do
  source 'ceph/ceph.conf.erb'

  networks = node['bcpc']['networking']['topology']['networks']
  primary = networks['primary']
  storage = networks['storage']

  nodes = is_init_cloud() ? [node] : get_headnodes()

  variables(
    :config => config,
    :public_network => primary['cidr'],
    :cluster_network => storage['cidr'],
    :nodes => nodes
  )
end

template '/etc/ceph/ceph.bootstrap-osd.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    :username => 'bootstrap-osd',
    :client => config['ceph']['bootstrap']['osd'],
    :caps => ['caps mon = "allow profile bootstrap-osd"']
  )
end

template '/etc/ceph/ceph.client.admin.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    :username => 'admin',
    :client => config['ceph']['client']['admin'],
    :caps => [
      'caps mds = "allow *"',
      'caps mgr = "allow *"',
      'caps mon = "allow *"',
      'caps osd = "allow *"'
    ]
  )
end

node['bcpc']['ceph']['osds'].each do |osd|

  execute "ceph-deploy osd create #{osd}" do
    cwd '/etc/ceph'

    command "ceph-deploy osd create $(hostname):#{osd}; sleep 5"

    only_if %Q[lsblk /dev/#{osd}]
    not_if %Q[blkid /dev/#{osd}1 | grep "ceph data"]
  end

end

# configure headnodes osds to have a low priority so they won't contain data
#
ruby_block "set primary anti-affinity for headnode osds" do
  block do

    osd_tree = JSON.parse( %x[ceph osd tree --format json] )
    host_node = osd_tree['nodes'].find{ |n| n['name'] == node['hostname'] }

    if not host_node.nil?
      host_node.fetch('children',{}).each do |osd_id|
        osd = osd_tree['nodes'].find{ |n| n['id'] == osd_id}
        if osd['primary_affinity'] != 0
          %x[ceph osd primary-affinity osd.#{osd_id} 0]
        end
      end
    end

  end
  only_if { is_headnode(node) }
end


# TODO configure crush map rules (ie: rack location)
