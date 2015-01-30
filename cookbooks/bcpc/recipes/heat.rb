#
# Cookbook Name:: bcpc
# Recipe:: heat
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

include_recipe "bcpc::mysql-head"
include_recipe "bcpc::openstack"

ruby_block "initialize-heat-config" do
    block do
        make_config('mysql-heat-user', "heat")
        make_config('mysql-heat-password', secure_password)
    end
end

%w{heat-api heat-api-cfn heat-engine}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [:enable, :start]
    end
end

service "heat-api" do
    restart_command "service heat-api restart; sleep 5"
end

template "/etc/heat/heat.conf" do
    source "heat.conf.erb"
    owner "heat"
    group "heat"
    mode 00600
    notifies :restart, "service[heat-api]", :delayed
    notifies :restart, "service[heat-api-cfn]", :delayed
    notifies :restart, "service[heat-engine]", :delayed
end

directory "/etc/heat/environment.d" do
    user "heat"
    group "heat"
    mode 00755
end

ruby_block "heat-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['heat']}\"'|grep \"#{node['bcpc']['dbname']['heat']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['heat']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['heat']}.* TO '#{get_config('mysql-heat-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-heat-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['heat']}.* TO '#{get_config('mysql-heat-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-heat-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[heat-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "heat-database-sync" do
    action :nothing
    user "root"
    code "heat-manage db_sync"
    notifies :restart, "service[heat-api]", :immediately
    notifies :restart, "service[heat-api-cfn]", :immediately
    notifies :restart, "service[heat-engine]", :immediately
end
