#
# Cookbook Name:: bcpc-proxysql
# Recipe:: default
#
# Copyright 2016, Bloomberg Finance L.P.
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

include_recipe 'bcpc-proxysql::logrotate'

package 'proxysql'

service 'proxysql' do
  provider Chef::Provider::Service::Init::Debian
  action [:enable, :start]
  restart_command \
    '/etc/init.d/proxysql stop; sudo -u proxysql /usr/bin/proxysql \
    -c /etc/proxysql.cnf -D /var/lib/proxysql --reload ; sleep 5'
end

# Create a user on cluster database for ProxySQL backend health check
ruby_block 'grant-usage-to-proxysql-monitor-user' do
  block do
    grant_monitor_user_cmd = %(
      export MYSQL_PWD=#{get_config('mysql-root-password')};
      mysql -u root -e "GRANT USAGE ON *.* to \
      #{get_config('proxysql-monitor-user')}@'%' IDENTIFIED BY \
      '#{get_config('proxysql-monitor-password')}';"
    )
    cmd = Mixlib::ShellOut.new(grant_monitor_user_cmd)
    cmd.run_command
    cmd.error!
  end
end

# Construct attributes for later template generation
servers = []
heads = get_head_nodes
heads.each do |h|
  servers.push(
    'address' => h['bcpc']['management']['ip'],
    'hostgroup' => 1,
    'port' => node['bcpc-proxysql']['mysql_servers']['port'],
    'weight' => node['bcpc-proxysql']['mysql_servers']['weight'],
    'max_connections' => \
      node['bcpc-proxysql']['mysql_servers']['max_connections'],
    'max_latency_ms' => \
      node['bcpc-proxysql']['mysql_servers']['max_latency_ms']
  )
end
node.set['bcpc-proxysql']['generated']['mysql_servers'] = servers

admin_variables = {
  'admin_credentials' => \
    get_config('proxysql-admin-user') + ':' + \
    get_config('proxysql-admin-password')
}
admin_variables.merge(node['bcpc-proxysql']['admin_variables'])

mysql_users = []
%w( cinder glance keystone nova nova-api pdns ).each do |component|
  mysql_users.push(
    {
      'username' => make_config("mysql-#{component}-user", component),
      'password' => make_config("mysql-#{component}-password", secure_password),
      'default_schema' => component.tr('-', '_')
    }
  )
end
mysql_users.push(
  {
    'username' => make_config('mysql-backup-user', 'mysql_backup'),
    'password' => make_config('mysql-backup-password', secure_password),
    'default_schema' => 'information_schema'
  }
)
# end attribute construction

template '/etc/proxysql-admin.cnf' do
  source 'proxysql-admin.cnf.erb'
  mode 00600
  owner 'proxysql'
  group 'proxysql'
  variables(
    :proxysql_admin_config => node['bcpc-proxysql']['admin']['config']
  )
end

template '/etc/proxysql.cnf' do
  source 'proxysql.cnf.erb'
  mode 00600
  owner 'proxysql'
  group 'proxysql'
  variables(
    :admin_variables   => admin_variables,
    :mysql_variables   => node['bcpc-proxysql']['mysql_variables'],
    :mysql_servers     => servers,
    :mysql_users       => mysql_users,
    :mysql_query_rules => node['bcpc-proxysql']['mysql_query_rules']
  )
  notifies :restart, 'service[proxysql]', :immediately
end

include_recipe 'bcpc-proxysql::admin_db'
