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

ruby_block "nova-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['nova']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-nova-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-nova-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[nova-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['nova']}\"'|grep \"#{node['bcpc']['dbname']['nova']}\" >/dev/null" }
end

# Nova API database needed by Liberty or higher
ruby_block "nova-api-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['nova_api']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova_api']}.* TO '#{get_config('mysql-nova-api-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-nova-api-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova_api']}.* TO '#{get_config('mysql-nova-api-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-nova-api-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[nova-api-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['nova_api']}\"'|grep \"#{node['bcpc']['dbname']['nova_api']}\" >/dev/null" }
end

ruby_block 'update-nova-db-schemas' do
  block do
    self.notifies :run, "bash[nova-database-sync]", :immediately
    self.notifies :run, "bash[nova-api-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if { ::File.exist?('/usr/local/etc/openstack_upgrade') }
end

bash "nova-database-sync" do
    action :nothing
    user "root"
    code "nova-manage db sync"
end

bash "nova-api-database-sync" do
    action :nothing
    user "root"
    code "nova-manage api_db sync"
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

cookbook_file '/usr/lib/python2.7/dist-packages/nova/scheduler/weights/bbweigher.py' do
  source 'bbweigher.py'
  mode   '00644'
  owner  'root'
  group  'root'
  notifies :restart, "service[nova-scheduler]", :delayed
end

# Configure the nova keystone bits
# https://docs.openstack.org/mitaka/install-guide-ubuntu/nova.html
domain = node['bcpc']['keystone']['service_project']['domain']
nova_username = node['bcpc']['nova']['user']
nova_project_name = node['bcpc']['keystone']['service_project']['name']
admin_role_name = node['bcpc']['keystone']['admin_role']

ruby_block 'keystone-create-nova-user' do
  block do
    cmd = "openstack user create --domain #{domain} " +
          "--password #{get_config('keystone-nova-password')} #{nova_username}"
    execute_in_keystone_admin_context(cmd)
  end
  not_if {
    cmd = "openstack user show --domain #{domain} #{nova_username}"
    execute_in_keystone_admin_context(cmd)
  }
end

ruby_block 'keystone-assign-nova-admin-role' do
  opts = [
    "--user-domain #{domain}",
    "--project-domain #{domain}",
    "--user #{nova_username}",
    "--project #{nova_project_name}"
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

# NOTE(kamidzi): The boundaries of separation amongst all these nova-* recipes are of questionable intent
# Write out cinder openrc
template '/root/openrc-nova' do
  source 'keystone/openrc.erb'
  mode '0600'
  variables(
    lazy {
      {
        username: nova_username,
        password: get_config('keystone-nova-password'),
        project_name: nova_project_name,
        domain: domain
      }
    }
  )
end

include_recipe "bcpc::nova-work"
include_recipe 'bcpc::openstack-network-setup'
