#
# Cookbook Name:: bcpc
# Recipe:: calico-compute
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

include_recipe 'bcpc::etcd-common'
include_recipe 'bcpc::bird-compute'
include_recipe 'bcpc::neutron-common'
include_recipe 'bcpc::packages-calico'

file '/etc/init/neutron-dhcp-agent.override' do
  content 'manual'
  owner   'root'
  group   'root'
  mode    '00644'
end

%w(
  dnsmasq-base
  dnsmasq-utils
  calico-compute
  neutron-dhcp-agent
  neutron-metadata-agent
  calico-dhcp-agent
).each do |pkg|
  package pkg do
    action :upgrade
  end
end

service 'neutron-dhcp-agent' do
  action [:stop, :disable]
end

template '/etc/neutron/metadata_agent.ini' do
  source 'neutron.metadata_agent.ini.erb'
  owner  'root'
  group  'root'
  mode   '00644'
  notifies :restart, 'service[neutron-metadata-agent]', :immediately
end

template '/etc/neutron/dhcp_agent.ini' do
  source 'neutron.dhcp_agent.ini.erb'
  owner  'root'
  group  'root'
  mode   '00644'
  notifies :restart, 'service[calico-dhcp-agent]', :immediately
end

template '/etc/calico/felix.cfg' do
  source 'felix.cfg.erb'
  owner  'root'
  group  'root'
  mode   '00644'
  notifies :restart, 'service[calico-felix]', :immediately
end

%w(neutron-metadata-agent calico-dhcp-agent calico-felix).each do |svc|
  service svc do
    action [:start, :enable]
    subscribes :restart, 'template[/etc/neutron/neutron.conf]', :delayed
  end
end
