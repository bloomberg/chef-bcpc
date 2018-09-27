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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
policy_dir = '/etc/openstack-dashboard/conf'

package 'openstack-dashboard'

service 'horizon' do
  service_name 'apache2'
end

directory policy_dir do
  action :create
end

%w(keystone neutron glance).each do |srv|
  remote_file "#{policy_dir}/#{srv}_policy.json" do
    source "file:///etc/#{srv}/policy.json"
  end
end

%w(nova cinder).each do |srv|
  execute "generate #{srv} policy files" do
    command <<-EOH
      oslopolicy-sample-generator \
        --format json \
        --namespace #{srv} \
        --output-file #{policy_dir}/#{srv}_policy.json
    EOH
  end
end

template '/etc/apache2/conf-available/openstack-dashboard.conf' do
  source 'horizon/apache-openstack-dashboard.conf.erb'
  notifies :restart, 'service[horizon]', :immediately
end

template '/etc/openstack-dashboard/local_settings.py' do
  source 'horizon/local_settings.py.erb'
  variables(
    config: config,
    headnodes: headnodes(all: true),
    domains: node['bcpc']['keystone'].fetch('domains', [])
  )
  notifies :restart, 'service[horizon]', :delayed
end
