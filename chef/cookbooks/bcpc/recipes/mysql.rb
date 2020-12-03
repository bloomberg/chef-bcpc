# Cookbook:: bcpc
# Recipe:: mysql
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

repo = node['bcpc']['mysql']['repo']
codename = node['lsb']['codename']

apt_repository 'percona' do
  uri repo['url']
  distribution codename
  components ['main']
  key repo['key']
  only_if { repo['enabled'] }
end

package %w(
  debconf-utils
  percona-xtradb-cluster-57
)

service 'mysql'
service 'xinetd'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
mysqladmin = mysqladmin()
mysql_init_db_file = "#{Chef::Config[:file_cache_path]}/mysql-init-db.sql"
mysql_init_done_file = '/var/lib/mysql/done'

file mysql_init_db_file do
  action :nothing
end

template mysql_init_db_file do
  source 'mysql/init.sql.erb'

  variables(
    users: config['mysql']['users']
  )

  notifies :run, 'bash[configure mysql db]', :immediately
  not_if { ::File.exist?(mysql_init_done_file) }
end

bash 'configure mysql db' do
  action :nothing
  code <<-EOH
    mysql -u #{mysqladmin['username']} < #{mysql_init_db_file} && \
    touch #{mysql_init_done_file}
  EOH
  notifies :delete, "file[#{mysql_init_db_file}]", :immediately
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
