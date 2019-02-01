# Cookbook Name:: bcpc
# Recipe:: ssh
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

listen_addresses = [node['service_ip']]

node['host_vars']['interfaces']['transit'].each do |transit|
  listen_addresses.append(get_address(transit['ip']))
end

service 'ssh'

directory '/root/.ssh' do
  mode '700'
end

file '/root/.ssh/authorized_keys' do
  mode '640'
  content Base64.decode64(config['ssh']['public'])
end

file '/root/.ssh/id_ed25519' do
  mode '600'
  content Base64.decode64(config['ssh']['private'])
end

template '/root/.ssh/known_hosts' do
  source 'ssh/known_hosts.erb'
  mode '644'
  variables(
    nodes: all_nodes
  )
end

template '/etc/ssh/sshd_config' do
  source 'ssh/sshd_config.erb'
  variables(
    listen_addresses: listen_addresses
  )
  notifies :restart, 'service[ssh]', :immediately
end
