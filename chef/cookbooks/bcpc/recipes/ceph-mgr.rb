# Cookbook:: bcpc
# Recipe:: ceph-mgr
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

return unless node['bcpc']['ceph']['mgr']['enabled']

include_recipe 'bcpc::ceph-packages'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

template '/var/lib/ceph/bootstrap-mgr/ceph.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-mgr',
    client: config['ceph']['bootstrap']['mgr'],
    caps: ['caps mon = "allow profile bootstrap-mgr"']
  )
end

execute 'create ceph mgr daemon' do
  cwd '/etc/ceph'
  command "ceph-deploy mgr create #{node['hostname']}"
  creates "/var/lib/ceph/mgr/ceph-#{node['hostname']}/done"
end

execute 'configure progress module' do
  command "ceph progress #{node['bcpc']['ceph']['module']['progress']['enabled'] ? 'on' : 'off'}"
  not_if "ceph config get mgr mgr/progress/enabled | grep -w #{node['bcpc']['ceph']['module']['progress']['enabled']}"

  # Guard to avoid racing for module configuration prior before mgrs are fully up
  retries 6
  retry_delay 10
end
