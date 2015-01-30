#
# Cookbook Name:: bcpc
# Recipe:: ceilometer-head
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
include_recipe "bcpc::ceilometer-common"

%w{ceilometer-api ceilometer-collector ceilometer-agent-central}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [:enable, :start]
        subscribes :restart, "template[/etc/ceilometer/ceilometer.conf]", :delayed
    end
end

ruby_block "ceilometer-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['ceilometer']}\"'|grep \"#{node['bcpc']['dbname']['ceilometer']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['ceilometer']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['ceilometer']}.* TO '#{get_config('mysql-ceilometer-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-ceilometer-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['ceilometer']}.* TO '#{get_config('mysql-ceilometer-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-ceilometer-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[ceilometer-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "ceilometer-database-sync" do
    action :nothing
    user "root"
    code "ceilometer-dbsync"
    notifies :restart, "service[ceilometer-api]", :immediately
    notifies :restart, "service[ceilometer-collector]", :immediately
    notifies :restart, "service[ceilometer-agent-central]", :immediately
end

include_recipe "bcpc::ceilometer-work"
