# Cookbook:: bcpc-consul
# Recipe:: consul
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

include_recipe 'bcpc::consul-package'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

service 'consul'

directory '/usr/local/bcpc/bin' do
  recursive true
end

%w(
  if_leader
  if_primary_mysql.sh
  if_not_primary_mysql.sh
  if_primary_proxysql.sh
  if_not_primary_proxysql.sh
  if_leader
  proxysql-check-helper
).each do |script|
  template "/usr/local/bcpc/bin/#{script}" do
    variables(
      config: config
    )
    source "consul/#{script}.erb"
    mode '755'
  end
end

node['bcpc']['consul']['services'].each do |s|
  fp = s['check']['args'][0]
  fn = File.basename(fp)

  cookbook_file fp do
    source "consul/#{fn}"
    mode '755'
  end
end

node['bcpc']['consul']['watches'].each do |w|
  fp = w['args'][0]
  fn = File.basename(fp)

  template fp do
    source "consul/#{fn}.erb"
    mode '755'
  end
end

file "#{node['bcpc']['consul']['conf_dir']}/watches.json" do
  watches = { 'watches' => node['bcpc']['consul']['watches'] }
  content JSON.pretty_generate(watches)
  notifies :reload, 'service[consul]', :immediately
end

file "#{node['bcpc']['consul']['conf_dir']}/services.json" do
  services = { 'services' => node['bcpc']['consul']['services'] }
  content JSON.pretty_generate(services)
  notifies :restart, 'service[consul]', :immediately
end

begin
  config = node['bcpc']['consul']['config']

  if init_cloud?
    config = config.merge('bootstrap' => true)
  else
    headnodes = headnodes(exclude: node['hostname'])
    retry_join = headnodes.collect { |h| h['service_ip'].to_s }
    config = config.merge('bootstrap' => false, 'retry_join' => retry_join)
  end

  file "#{node['bcpc']['consul']['conf_dir']}/config.json" do
    content JSON.pretty_generate(config)
    notifies :restart, 'service[consul]', :immediately
  end
end

# Delete old consul scripts, if present
# NOTE: This code only needs to execute once in a cluster's lifetime and should
# be removed once no longer needed or a better cleanup method is devised (e.g.
# ansible playbooks).
%w(
  haproxy-watch
  mysql-elect-watch
  mysql-watch
  dns-watch
).each do |script|
  file "/usr/local/bcpc/bin/#{script}" do
    action :delete
  end
end

execute 'wait for consul leader' do
  retries 10
  command <<-DOC
    curl -q http://localhost:8500/v1/status/leader | grep -q \:8300
  DOC
end
