#
# Cookbook Name:: bcpc-openstack-nova
# Recipe:: headnode
#
# Copyright 2015, Bloomberg Finance L.P.
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

include_recipe 'bcpc-mysql::headnode'
include_recipe 'bcpc-openstack-nova'

ruby_block "nova-database-creation" do
  block do
    cmd = Mixlib::ShellOut.new(<<-EOH
      export MYSQL_PWD=#{get_config('mysql-root-password')};
      mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['nova']};"
      mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
      mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
      mysql -uroot -e "FLUSH PRIVILEGES;"
      EOH
    ).run_command
    cmd.error!
    self.notifies :run, "bash[nova-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if {
    cmd = Mixlib::ShellOut.new(<<-EOH
      MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = "#{node['bcpc']['dbname']['nova']}"'
      EOH
    ).run_command
    cmd.stdout.empty?
  }
end

bash "nova-database-sync" do
    action :nothing
    user "root"
    code "nova-manage db sync"
end

%w{nova-scheduler nova-cert nova-consoleauth nova-conductor}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [:enable, :start]
        subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
        subscribes :restart, "template[/etc/nova/api-paste.ini]", :delayed
    end
end

include_recipe 'bcpc-openstack-nova::compute'
include_recipe 'bcpc-openstack-nova::network-setup'
include_recipe 'bcpc-openstack-nova::flavors'
include_recipe 'bcpc-openstack-nova::custom-metadata'
include_recipe 'bcpc-openstack-nova::host-aggregates'
