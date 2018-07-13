# Cookbook Name:: bcpc
# Recipe:: haproxy
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

apt_repository 'haproxy' do
  uri node['bcpc']['haproxy']['apt']['url']
  distribution node['lsb']['codename']
  components ['main']
  key 'haproxy/haproxy.key'
  only_if { node['bcpc']['haproxy']['apt']['enabled'] }
end

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

package 'haproxy'
service 'haproxy'

template '/etc/haproxy/haproxy.pem' do
  source 'haproxy/haproxy.pem.erb'
  mode '600'

  inter = config['ssl']['intermediate']
  inter = inter ? Base64.decode64(inter) : false

  variables(
    key: Base64.decode64(config['ssl']['key']),
    crt: Base64.decode64(config['ssl']['crt']),
    inter: inter
  )

  notifies :restart, 'service[haproxy]', :delayed
end

template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy/haproxy.cfg.erb'
  variables(
    nodes: get_headnodes(all: true),
    user: config['haproxy'],
    vip: get_address(node['bcpc']['cloud']['vip']['ip']),
    max_connections: node['bcpc']['mysql']['max_connections']
  )
  notifies :restart, 'service[haproxy]', :immediately
end
