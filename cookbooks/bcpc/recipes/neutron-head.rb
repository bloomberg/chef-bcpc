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

ruby_block 'keystone-create-neutron-user' do
  block do
    cmd = "openstack user create --domain #{domain} " +
          "--password #{get_config('keystone-neutron-password')} #{neutron_username}"
    execute_in_keystone_admin_context(cmd)
  end
  not_if {
    cmd = "openstack user show --domain #{domain} #{neutron_username}"
    execute_in_keystone_admin_context(cmd)
  }
end

ruby_block 'keystone-assign-neutron-admin-role' do
  opts = [
    "--user-domain #{domain}",
    "--project-domain #{domain}",
    "--user #{neutron_username}",
    "--project #{neutron_project_name}"
  ]
  block do
    cmd = "openstack role add " + opts.join(' ') + ' ' + admin_role_name
    execute_in_keystone_admin_context(cmd)
  end
  not_if {
    cmd = 'openstack role assignment list '
    g_opts = opts + [
      '-f value -c Role',
      "--role #{admin_role_name}",
      "| grep ^#{get_keystone_role_id(admin_role_name)}$"
    ]
    cmd += g_opts.join(' ')
    execute_in_keystone_admin_context(cmd)
  }
end

# Write out neutron openrc
template '/root/openrc-neutron' do
  source 'keystone/openrc.erb'
  mode '0600'
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
