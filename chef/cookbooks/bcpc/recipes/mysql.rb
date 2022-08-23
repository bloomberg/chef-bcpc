# Cookbook:: bcpc
# Recipe:: mysql
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

# Add the appropriate Percona repo
include_recipe 'bcpc::percona-apt'

package %w(
  debconf-utils
  percona-xtradb-cluster
)

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
mysqladmin = mysqladmin()

template '/root/.my.cnf' do
  source 'mysql/root.my.cnf.erb'
  sensitive true
  variables(
    mysqladmin: mysqladmin
  )
end

# Configure xinetd to report MySQL clustering status (for Consul).
service 'xinetd'

execute 'add mysqlchk to /etc/services' do
  command <<-DOC
    printf "mysqlchk\t3307/tcp\n" >> /etc/services
  DOC
  not_if 'grep mysqlchk /etc/services'
end

template '/etc/xinetd.d/mysqlchk' do
  source 'mysql/xinetd-mysqlchk.erb'
  mode '640'
  variables(
    user: {
      'username' => 'check',
      'password' => config['mysql']['users']['check']['password'],
    }
  )
  notifies :restart, 'service[xinetd]', :immediately
end

# See below -- defer service restarts until the end of the recipe
# if any of these MySQL/WSREP configuration files change.
template '/etc/mysql/my.cnf' do
  source 'mysql/my.cnf.erb'
  notifies :run, 'ruby_block[recipe-deferred mysql restart]', :immediately
end

template '/etc/mysql/debian.cnf' do
  source 'mysql/debian.cnf.erb'
  variables(
    mysqladmin: mysqladmin
  )
  notifies :run, 'ruby_block[recipe-deferred mysql restart]', :immediately
end

template '/etc/mysql/conf.d/wsrep.cnf' do
  source 'mysql/wsrep.cnf.erb'
  variables(
    config: config,
    headnodes: headnodes(exclude: node['hostname'])
  )
  notifies :run, 'ruby_block[recipe-deferred mysql restart]', :immediately
end

# MySQL/PXC does not respond well to multiple service restarts
# (e.g., if/when each configuration file changes when a cluster is
# bootstrapped, and each change notifies the service to restart).
#
# At the same time, Chef does not support end-of-recipe deferred
# notifications. But, we can still do that with ruby_blocks:
ruby_block 'recipe-deferred mysql restart' do
  action :nothing
  block do
    node.run_state['mysql_restart'] = true
  end
end

service 'mysql' do
  action :restart
  only_if { node.run_state.fetch('mysql_restart', false) }
end

# When the first node is bootstrapped, we need to define users, etc.
mysql_init_db_file = "#{Chef::Config[:file_cache_path]}/mysql-init-db.sql"

file mysql_init_db_file do
  action :nothing
end

template mysql_init_db_file do
  source 'mysql/init.sql.erb'
  variables(
    users: config['mysql']['users']
  )
  only_if { init_mysql? }
end

bash 'bootstrap mysql' do
  code <<-EOH
    mysql -u #{mysqladmin['username']} < #{mysql_init_db_file}
  EOH
  notifies :delete, "file[#{mysql_init_db_file}]", :immediately
  only_if { init_mysql? }
end

# Wait until Consul elects the primary database instance.
execute 'wait for consul to elect the primary mysql host' do
  retries 30
  command 'getent hosts primary.mysql.service.consul'
end
