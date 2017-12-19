#
# Cookbook Name:: bcpc
# Recipe:: neutron-head
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

return unless node['bcpc']['enabled']['neutron']

include_recipe "bcpc::neutron-common"

ruby_block "neutron-database-creation" do
  block do
    %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
        mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['neutron']};"
        mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['neutron']}.* TO '#{get_config('mysql-neutron-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-neutron-password')}';"
        mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['neutron']}.* TO '#{get_config('mysql-neutron-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-neutron-password')}';"
        mysql -uroot -e "FLUSH PRIVILEGES;"
    ]
    self.notifies :run, "bash[neutron-database-sync]", :immediately
    self.resolve_notification_references
  end
  not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['neutron']}\"'|grep \"#{node['bcpc']['dbname']['neutron']}\" >/dev/null" }
end

package 'neutron-server' do
  action :upgrade
end

service 'neutron-server' do
  action [:enable, :start]
  subscribes :restart, "template[/etc/neutron/neutron.conf]", :delayed
  subscribes :restart, "template[/etc/neutron/plugins/ml2/ml2_conf.ini]", :delayed
  subscribes :restart, "template[/etc/neutron/policy.json]", :delayed
end

bash "neutron-database-sync" do
  action :nothing
  user "root"
  code "neutron-db-manage upgrade heads"
end

domain = node['bcpc']['keystone']['service_project']['domain']
neutron_username = node['bcpc']['neutron']['user']
neutron_project_name = node['bcpc']['keystone']['service_project']['name']

ruby_block "keystone-create-neutron-user" do
  block do
    execute_in_keystone_admin_context("openstack user create --domain #{domain} --password #{get_config('keystone-neutron-password')} #{neutron_username}")
  end
  not_if {
    cmd = "openstack user show --domain #{domain} #{neutron_username}"
    s = execute_in_keystone_admin_context(cmd){|o,e,s| s}
    s.success?
  }
end

ruby_block "keystone-assign-neutron-admin-role" do
  block do
    execute_in_keystone_admin_context("openstack role add --project-domain #{domain} --user-domain #{domain} --project #{neutron_project_name} --user #{neutron_username} #{node['bcpc']['keystone']['admin_role']}")
  end
  # NOTE(kmidzi): below command always returns, so check for valid json output; break pattern with only_if
  only_if {
    begin
      r = JSON.parse execute_in_keystone_admin_context("openstack role assignment list --role #{node['bcpc']['keystone']['admin_role']} --project-domain #{domain} --user-domain #{domain} --project #{neutron_project_name} --user #{neutron_username} -fjson")
      r.empty?
    rescue JSON::ParserError
      true
    end
  }
end

# Write out neutron openrc
template "/root/neutron-openrc" do
  source "keystone/openrc.erb"
  owner neutron_username
  group neutron_username
  mode "0600"
  variables(
    lazy {
      {
        username: neutron_username,
        password: get_config('keystone-neutron-password'),
        project_name: neutron_project_name,
        domain: domain
      }
    }
  )
end

include_recipe 'bcpc::calico-head'
