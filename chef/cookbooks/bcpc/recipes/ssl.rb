# Cookbook:: bcpc
# Recipe:: ssl
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

directory '/etc/ssl/private' do
  mode '700'
end

file '/etc/ssl/private/ssl-bcpc.key' do
  content Base64.decode64(config['ssl']['key'])
end

file '/usr/local/share/ca-certificates/ssl-bcpc.crt' do
  content Base64.decode64(config['ssl']['crt'])
  notifies :run, 'execute[update ca-certificates]', :immediately
end

begin
  intermediate = config['ssl']['intermediate']
  intermediate = Base64.decode64(intermediate) unless intermediate.nil?

  file '/usr/local/share/ca-certificates/ssl-bcpc-intermediate.crt' do
    content intermediate
    notifies :run, 'execute[update ca-certificates]', :immediately
    not_if { intermediate.nil? }
  end
end

execute 'update ca-certificates' do
  action :nothing
  command 'update-ca-certificates'
end
