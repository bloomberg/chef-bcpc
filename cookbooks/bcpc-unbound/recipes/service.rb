#
# Cookbook Name:: bcpc-unbound
# Recipe:: service
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

template '/etc/default/unbound' do
  source 'default.unbound.erb'
  owner node['bcpc-unbound']['username']
  group node['bcpc-unbound']['groupname']
  mode 00644
  variables(
    'config' => node['bcpc-unbound']['defaults']
  )
  notifies :restart, 'service[unbound]', :delayed
end

template "#{node['bcpc-unbound']['server']['directory']}/unbound.conf" do
  source 'unbound.conf.erb'
  owner node['bcpc-unbound']['username']
  group node['bcpc-unbound']['groupname']
  mode 00644
  variables(
    'config' => node['bcpc-unbound']['server']
  )
  notifies :restart, 'service[unbound]', :delayed
end

# Disable DNSSEC
file '/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf' do
  action :delete
  notifies :restart, 'service[unbound]', :immediate
end

service 'unbound' do
  supports status: true, restart: true, reload: true
  action %i[enable]
end
