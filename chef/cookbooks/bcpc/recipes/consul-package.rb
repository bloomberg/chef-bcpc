# Cookbook:: bcpc-consul
# Recipe:: install
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

package 'unzip'

consul_fn = node['bcpc']['consul']['remote_file']['file']
consul_fp = "#{Chef::Config[:file_cache_path]}/#{consul_fn}"

remote_file consul_fp do
  source "#{node['bcpc']['web_server']['url']}/#{consul_fn}"
  mode '755'
  checksum node['bcpc']['consul']['remote_file']['checksum']
  notifies :run, 'execute[unpack consul]', :immediately
  notifies :create, 'remote_file[install consul]', :immediately
end

execute 'unpack consul' do
  action :nothing
  cwd Chef::Config[:file_cache_path]
  command "unzip -o #{consul_fn}"
end

remote_file 'install consul' do
  action :nothing
  mode '755'
  path node['bcpc']['consul']['executable']
  source "file://#{Chef::Config[:file_cache_path]}/consul"
end

[
  node['bcpc']['consul']['conf_dir'],
  node['bcpc']['consul']['config']['data_dir'],
].each do |dir|
  directory dir do
    recursive true
  end
end

systemd_unit 'consul.service' do
  exec = node['bcpc']['consul']['executable']
  conf = node['bcpc']['consul']['conf_dir']

  content <<-DOC.gsub(/^\s+/, '')
    [Unit]
    Description=consul agent
    Requires=network-online.target
    After=network-online.target

    [Service]
    Type=simple
    Restart=on-failure
    ExecStart=#{exec} agent $OPTIONS -config-dir=#{conf}
    ExecReload=/bin/kill -HUP $MAINPID
    KillSignal=SIGINT
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=consul

    [Install]
    WantedBy=multi-user.target
  DOC

  action %i(create enable)
end
