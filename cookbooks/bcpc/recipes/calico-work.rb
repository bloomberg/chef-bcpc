#
# Cookbook Name:: bcpc
# Recipe:: calico-work
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
include_recipe 'bcpc::packages-calico'

%w[
  calico-common
  calico-compute
  calico-dhcp-agent
  calico-felix
].each do |pkg|
  package pkg do
    action :upgrade
  end
end

directory '/etc/calico'

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'
  variables(
    :etcd_nodes => ['http://localhost:2379']
  )
end

# these neutron services are installed/enabled by calico packages
# these services are superseded by nova-metadata-agent and calico-dhcp-agent
# so we don't need them to be enabled/running
#
service 'neutron-dhcp-agent' do
  action [:disable,:stop]
end

service 'neutron-metadata-agent' do
  action [:disable,:stop]
end

service 'calico-felix'
service 'calico-dhcp-agent'

template '/etc/neutron/neutron.conf' do
  source 'calico/neutron.conf.erb'
  owner 'root'
  group 'neutron'
  mode 00644
  notifies :restart, 'service[calico-dhcp-agent]', :immediately
end

template '/etc/systemd/system/calico-felix.service' do
  source 'calico/calico-felix.service'
  notifies :run, 'execute[systemctl daemon-reload]', :immediately
  notifies :restart, 'service[calico-felix]', :immediately
end

execute 'systemctl daemon-reload' do
  action :nothing
  command 'systemctl daemon-reload'
end
