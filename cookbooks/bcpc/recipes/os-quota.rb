# Cookbook Name:: bcpc
# Recipe:: quota
#
# Copyright 2015, Bloomberg Finance L.P.
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

cookbook_file '/usr/local/bin/set-os-quota.py' do
  source 'set-os-quota.py'
  owner 'root'
  mode '0755'
end

execute 'set-os-quota' do
  action :nothing
  command '. /root/openrc-nova; /usr/local/bin/if_vip /usr/local/bin/set-os-quota.py'
end

template '/usr/local/etc/os-quota.yml' do
  source 'os-quota.yml.erb'
  owner 'root'
  mode '0644'
  variables(
    :quota => node['bcpc']['quota'].to_hash.to_yaml
  )
  notifies :run, 'execute[set-os-quota]', :immediately
end
