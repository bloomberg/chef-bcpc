#
# Cookbook Name:: bcpc
# Recipe:: zabbix-work
#
# Copyright 2013, Bloomberg Finance L.P.
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

include_recipe "bcpc::default"

remote_file "/tmp/zabbix-agent.tar.gz" do
    source "#{get_binary_server_url}/zabbix-agent.tar.gz"
    owner "root"
    mode 00444
    not_if { File.exists?("/usr/local/sbin/zabbix_agentd") }
end

bash "install-zabbix-agent" do
    code "tar zxf /tmp/zabbix-agent.tar.gz -C /usr/local/ && rm /tmp/zabbix-agent.tar.gz"
    not_if { File.exists?("/usr/local/sbin/zabbix_agentd") }
end

user node[:bcpc][:zabbix][:user] do
    shell "/bin/false"
    home "/var/log"
    gid node[:bcpc][:zabbix][:group]
    system true
end

directory "/var/log/zabbix" do
    user node[:bcpc][:zabbix][:user]
    group node[:bcpc][:zabbix][:group]
    mode 00755
end

template "/etc/init/zabbix-agent.conf" do
    source "upstart-zabbix-agent.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[zabbix-agent]", :delayed
end

template "/usr/local/etc/zabbix_agent.conf" do
    source "zabbix_agent.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-agent]", :delayed
end

template "/usr/local/etc/zabbix_agentd.conf" do
    source "zabbix_agentd.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-agent]", :delayed
end

service "zabbix-agent" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
end

directory "/usr/local/bin/checks" do
  action :create
  owner  node[:bcpc][:zabbix][:user]
  group "root"
  mode 00775
end 

directory "/usr/local/etc/checks" do
  action  :create
  owner  node[:bcpc][:zabbix][:user]
  group "root"
  mode 00775
end 

%w{ float_ips }.each do |cc| 
  template  "/usr/local/etc/checks/#{cc}.yml" do
    source "checks/#{cc}.yml.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00640
  end
  
  cookbook_file "/usr/local/bin/checks/#{cc}" do
    source "checks/#{cc}"
    owner "root"
    mode "00755"
  end

  cron "check-#{cc}" do
    home "/var/lib/zabbix"
    user "zabbix"
    minute "0"
    path "/usr/local/bin:/usr/bin:/bin"
    command "zabbix_sender -c /usr/local/etc/zabbix_agentd.conf --key 'check.#{cc}' --value `check -f timeonly #{cc}`"
  end
end

cookbook_file "/usr/local/bin/zabbix_discover_buckets" do
  source "zabbix_discover_buckets"
  owner "root"
  mode "00755"
end
