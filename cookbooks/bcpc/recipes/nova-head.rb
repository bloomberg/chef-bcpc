#
# Cookbook Name:: bcpc
# Recipe:: nova-head
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
include_recipe "bcpc::nova-common"

%w{nova-scheduler nova-cert nova-consoleauth nova-conductor}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [:enable, :start]
        subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
        subscribes :restart, "template[/etc/nova/api-paste.ini]", :delayed
        subscribes :restart, "template[/etc/nova/policy.json]", :delayed
    end
end

ruby_block "nova-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['nova']}\"'|grep \"#{node['bcpc']['dbname']['nova']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['nova']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[nova-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "nova-database-sync" do
    action :nothing
    user "root"
    code "nova-manage db sync"
    notifies :restart, "service[nova-scheduler]", :immediately
    notifies :restart, "service[nova-cert]", :immediately
    notifies :restart, "service[nova-consoleauth]", :immediately
    notifies :restart, "service[nova-conductor]", :immediately
end

ruby_block "reap-dead-servers-from-nova" do
    block do
        all_hosts = search_nodes("recipe", "nova-work").collect { |x| x['hostname'] }
        nova_hosts = %x[nova-manage service list | awk '{print $2}' | grep -ve "^Host$" | uniq].split
        nova_hosts.each do |host|
            if not all_hosts.include?(host)
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['nova']} -e "DELETE FROM services WHERE host=\\"#{host}\\";"
                    mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['nova']} -e "DELETE FROM compute_nodes WHERE hypervisor_hostname=\\"#{host}\\";"
                ]
            end
        end
    end
end

include_recipe "bcpc::nova-work"
