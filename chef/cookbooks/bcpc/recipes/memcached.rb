# Cookbook:: bcpc
# Recipe:: memcached
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

package 'memcached'
service 'memcached'

file '/var/log/memcached.log' do
  mode '644'
  owner 'memcache'
  group 'memcache'
end

template '/etc/memcached.conf' do
  source 'memcached/memcached.conf.erb'
  variables(
    verbose: node['bcpc']['memcached']['debug'],
    connections: node['bcpc']['memcached']['connections']
  )
  notifies :restart, 'service[memcached]', :immediately
end

logrotate_app 'memcached' do
  path '/var/log/memcached.log'
  frequency 'daily'
  rotate 10
  options %w(compress delaycompress notifempty copytruncate)
end
