#
# Cookbook Name:: bcpc-prometheus-exporter
# Recipe:: default
#
# Copyright 2016, Bloomberg Finance L.P.
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

group node['bcpc-prometheus-exporter']['group']

user node['bcpc-prometheus-exporter']['user'] do
  comment 'Prometheus service user'
  gid node['bcpc-prometheus-exporter']['group']
  home "/home/#{node['bcpc-prometheus-exporter']['user']}"
  shell '/bin/false'
end

[
  node['bcpc-prometheus-exporter']['log_dir'],
  node['bcpc-prometheus-exporter']['etc_dir']
].sort.each do |dir|
  directory dir do
    owner node['bcpc-prometheus-exporter']['user']
    group node['bcpc-prometheus-exporter']['group']
    mode 00750
  end
end

logrotate_app 'prometheus-exporter' do
  cookbook 'logrotate'
  path "#{node['bcpc-prometheus-exporter']['log_dir']}/*.log"
  frequency node['bcpc-prometheus-exporter']['logrotate']['frequency']
  rotate node['bcpc-prometheus-exporter']['logrotate']['rotate']
  options node['bcpc-prometheus-exporter']['logrotate']['options']
end

node.default['bcpc-prometheus-exporter']['exporters'].sort.each \
do |exporter, val|
  case exporter
  when 'graphite_exporter'
    val['parameters']['graphite.listen-address'] = \
      "#{node['bcpc']['management']['ip']}:2013"

    map_file = "#{exporter}-mapping.conf"
    map_path = "#{node['bcpc-prometheus-exporter']['etc_dir']}/#{map_file}"
    template map_path do
      source "#{map_file}.erb"
      owner 'root'
      group 'root'
      mode 00644
    end
  end

  cookbook_file "#{node['bcpc-prometheus-exporter']['sbin_dir']}/#{exporter}" do
    source exporter
    cookbook 'bcpc-binary-files'
    owner 'root'
    group 'root'
    mode 00755
  end

  template "/etc/init/#{exporter}.conf" do
    source 'upstart-exporter.conf.erb'
    owner 'root'
    group 'root'
    mode 00644
    variables(
      exporter: exporter,
      user: node['bcpc-prometheus-exporter']['user'],
      log_file: node['bcpc-prometheus-exporter']['log_dir']\
                + "/#{exporter}.log",
      executable: "#{node['bcpc-prometheus-exporter']['sbin_dir']}/#{exporter}"
    )
    notifies :restart, "service[#{exporter}]", :delayed
  end

  template "/etc/default/#{exporter}" do
    source 'upstart-default-exporter.erb'
    owner 'root'
    group 'root'
    mode 00644
    variables(
      params: val['parameters']
    )
    notifies :restart, "service[#{exporter}]", :delayed
  end

  service exporter do
    action [:enable, :start]
  end
end
