#
# Cookbook Name:: bcpc-consul
# Recipe:: install
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

group node['bcpc-consul']['username']

user node['bcpc-consul']['username'] do
  gid node['bcpc-consul']['username']
  shell '/bin/sh'
end

[node['bcpc-consul']['conf_dir'],
 node['bcpc-consul']['data_dir']].each do |dir|
  directory dir do
    owner node['bcpc-consul']['username']
    group 'root'
    mode 00700
    recursive true
  end
end

cookbook_file node['bcpc-consul']['executable'] do
  source 'consul'
  cookbook 'bcpc-binary-files'
  owner 'root'
  group 'root'
  mode 00755
  notifies :restart, 'service[consul]', :delayed
end
