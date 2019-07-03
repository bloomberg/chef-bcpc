# Cookbook Name:: bcpc
# Recipe:: etcd-ssl
#
# Copyright 2019, Bloomberg Finance L.P.
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

group 'etcd' do
  action :create
  append true
end

directory node['bcpc']['etcd']['ssl']['dir'] do
  action :create
  recursive true
  mode '0750'
  owner 'root'
  group 'etcd'
end

# ca certificate
file node['bcpc']['etcd']['ca']['crt']['filepath'] do
  content Base64.decode64(config['etcd']['ssl']['ca']['crt'])
  mode '0640'
  owner 'root'
  group 'etcd'
end

# server and client key/certificate
%w(server client-ro client-rw).each do |type|
  %w(crt key).each do |pem|
    file node['bcpc']['etcd'][type][pem]['filepath'] do
      content Base64.decode64(config['etcd']['ssl'][type][pem])
      mode '0640'
      owner 'root'
      group 'etcd'
    end
  end
end
