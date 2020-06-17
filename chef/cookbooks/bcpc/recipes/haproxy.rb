# Cookbook:: bcpc
# Recipe:: haproxy
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

apt_repository 'haproxy' do
  uri node['bcpc']['haproxy']['apt']['url']
  components ['main']
  key 'haproxy/haproxy.key'
  only_if { node['bcpc']['haproxy']['apt']['enabled'] }
end

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

package 'haproxy'
service 'haproxy'

directory '/etc/haproxy/haproxy.d' do
  action :create
end

cookbook_file '/etc/default/haproxy' do
  source 'haproxy/default'
  notifies :restart, 'service[haproxy]', :immediately
end

begin

  certs = []
  certs.push(Base64.decode64(config['ssl']['key']))
  certs.push(Base64.decode64(config['ssl']['crt']))

  if config['ssl']['intermediate']
    certs.push(Base64.decode64(config['ssl']['intermediate']))
  end

  template '/etc/haproxy/haproxy.pem' do
    source 'haproxy/haproxy.pem.erb'
    mode '600'

    variables(
      certs: certs
    )

    notifies :restart, 'service[haproxy]', :delayed
  end

end

template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy/haproxy.cfg.erb'
  variables(
    user: config['haproxy'],
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :restart, 'service[haproxy]', :immediately
end
