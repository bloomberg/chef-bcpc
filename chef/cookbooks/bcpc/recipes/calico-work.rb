# Cookbook:: bcpc
# Recipe:: calico-work
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

include_recipe 'bcpc::etcd3gw'
include_recipe 'bcpc::calico-apt'

%w(
  calico-common
  calico-compute
  calico-dhcp-agent
  calico-felix
).each do |pkg|
  package pkg
end

# remove example felix cfg file
file '/etc/calico/felix.cfg.example' do
  action :delete
end

service 'calico-felix'
service 'calico-dhcp-agent'

# these neutron services are installed/enabled by calico packages
# these services are superseded by nova-metadata-agent and calico-dhcp-agent
# so we don't need them to be enabled/running
%w(neutron-dhcp-agent neutron-metadata-agent).each do |srv|
  service srv do
    action %i(disable stop)
  end
end

etcd_endpoints = ['https://127.0.0.1:2379']

template '/etc/calico/felix.cfg' do
  source 'calico/felix.cfg.erb'
  variables(
    etcd_endpoints: etcd_endpoints.join(',')
  )
  notifies :restart, 'service[calico-felix]', :immediately
end

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'
  variables(
    etcd_endpoints: etcd_endpoints.join(',')
  )
end

template '/etc/neutron/neutron.conf' do
  source 'calico/neutron.conf.erb'
  mode '644'
  owner 'root'
  group 'neutron'
  notifies :restart, 'service[calico-dhcp-agent]', :immediately
end
