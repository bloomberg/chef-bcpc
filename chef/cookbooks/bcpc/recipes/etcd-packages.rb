# Cookbook Name:: bcpc
# Recipe:: etcd-packages
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

fn = node['bcpc']['etcd']['remote']['file']
fp = "#{Chef::Config[:file_cache_path]}/#{fn}"

remote_file fp do
  source node['bcpc']['etcd']['remote']['source']
  mode '755'

  checksum node['bcpc']['etcd']['remote']['checksum']
  notifies :run, 'execute[unpack etcd]', :immediately
  notifies :create, 'remote_file[install etcd]', :immediately
  notifies :create, 'remote_file[install etcdctl]', :immediately
end

execute 'unpack etcd' do
  action :nothing
  cwd Chef::Config[:file_cache_path]
  command "tar -xf #{fn}"
end

remote_file 'install etcd' do
  action :nothing
  mode '755'
  path '/usr/local/bin/etcd'
  source "file://#{fp.chomp('.tar.gz')}/etcd"
end

remote_file 'install etcdctl' do
  action :nothing
  mode '755'
  path '/usr/local/bin/etcdctl'
  source "file://#{fp.chomp('.tar.gz')}/etcdctl"
end
