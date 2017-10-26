#
# Cookbook Name:: bcpc
# Recipe:: etcd-common
#
# Copyright 2017, Bloomberg Finance L.P.
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

return unless node['bcpc']['enabled']['neutron']

include_recipe 'bcpc::packages-calico'

# installs etcd from calico repo
%w(etcd python-etcd).each do |pkg|
  package pkg do
    action :upgrade
  end
end

etcd_data_dir = '/var/lib/etcd/default'

directory etcd_data_dir do
  owner 'etcd'
  group 'etcd'
  mode  '00700'
end

template '/etc/default/etcd' do
  source 'etc_default_etcd.erb'
  owner  'root'
  group  'root'
  mode   '00644'
  variables(
    lazy {
      {
        etcd_data_dir: etcd_data_dir,
        headnodes: get_head_nodes
      }
    }
  )
  notifies :restart, 'service[etcd]', :immediately
end

service 'etcd' do
  action [:enable, :start]
end
