# Cookbook:: bcpc
# Recipe:: mysql
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

apt_repository 'percona' do
  uri node['bcpc']['mysql']['apt']['url']
  distribution node['lsb']['codename']
  components ['main']
  key 'mysql/release.key'
  only_if { node['bcpc']['mysql']['apt']['enabled'] }
end

package 'debconf-utils'
package 'percona-xtradb-cluster-57'

service 'mysql'
service 'xinetd'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
mysqladmin = mysqladmin()

file '/tmp/mysql-init-db.sql' do
  action :nothing
end

template '/tmp/mysql-init.sql' do
  source 'mysql/init.sql.erb'

  variables(
    users: config['mysql']['users']
  )

  notifies :run, 'execute[configure mysql db]', :immediately

  not_if <<-DOC
    mysql -u #{mysqladmin['username']} mysql \
      -e 'select user from user' | grep sst
  DOC
end

execute 'configure mysql db' do
  action :nothing
  command "mysql -u #{mysqladmin['username']} < /tmp/mysql-init.sql"
  notifies :delete, 'file[/tmp/mysql-init-db.sql]', :immediately
end

template '/root/.my.cnf' do
  source 'mysql/root.my.cnf.erb'
  sensitive true
  variables(
    mysqladmin: mysqladmin
  )
end

template '/etc/mysql/my.cnf' do
  source 'mysql/my.cnf.erb'
  notifies :restart, 'service[mysql]', :immediately
end

template '/etc/mysql/debian.cnf' do
  source 'mysql/debian.cnf.erb'
  variables(
    mysqladmin: mysqladmin
  )
  notifies :reload, 'service[mysql]', :immediately
end

template '/etc/mysql/conf.d/wsrep.cnf' do
  source 'mysql/wsrep.cnf.erb'

  variables(
    config: config,
    headnodes: headnodes(exclude: node['hostname'])
  )

  notifies :restart, 'service[mysql]', :immediately
end

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
