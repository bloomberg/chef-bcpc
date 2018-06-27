#
# Cookbook Name:: bcpc
# Recipe:: horizon
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
region = node['bcpc']['cloud']['region']
config = data_bag_item(region,'config')

package 'openstack-dashboard'

service 'horizon' do
  service_name 'apache2'
end

template '/etc/apache2/conf-available/openstack-dashboard.conf' do
  source 'horizon/apache-openstack-dashboard.conf.erb'
  notifies :reload, 'service[horizon]', :immediately
end

template '/etc/openstack-dashboard/local_settings.py' do
  source 'horizon/local_settings.py.erb'
  variables(
    :config => config,
    :nodes => get_headnodes(all:true)
  )
  notifies :restart, 'service[horizon]', :delayed
end

=begin

# this adds a way to override and customize Horizon's behavior
horizon_customize_dir = ::File.join('/', 'usr', 'local', 'bcpc-horizon', 'bcpc')
directory horizon_customize_dir do
  action    :create
  recursive true
end

file ::File.join(horizon_customize_dir, '__init__.py') do
  action :create
end

template ::File.join(horizon_customize_dir, 'overrides.py') do
  source   'horizon.overrides.py.erb'
  notifies :restart, 'service[apache2]', :delayed
end

horizon_policy_path = \
  '/usr/share/openstack-dashboard/openstack_dashboard/conf/'

%w[cinder glance heat keystone nova].each do |component|
  template horizon_policy_path + component + '_policy.json' do
    source "#{component}-policy.json.erb"
    owner 'root'
    group 'root'
    mode 00644
    variables('policy' =>
              JSON.pretty_generate(node['bcpc'][component]['policy']))
  end
end
=end
