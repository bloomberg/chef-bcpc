#
# Cookbook Name:: bcpc
# Recipe:: mysql-head
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

include_recipe "bcpc::packages-mysql"

ruby_block "initialize-mysql-config" do
    block do
        make_config('mysql-root-user', "root")
        make_config('mysql-root-password', secure_password)
        make_config('mysql-galera-user', "sst")
        make_config('mysql-galera-password', secure_password)
        make_config('mysql-check-user', "check")
        make_config('mysql-check-password', secure_password)
    end
end

ruby_block "initial-mysql-config" do
    block do
        %x[ mysql -u root -e "DELETE FROM mysql.user WHERE user='';"
            mysql -u root -e "UPDATE mysql.user SET password=PASSWORD('#{get_config('mysql-root-password')}') WHERE user='root'; FLUSH PRIVILEGES;"
            export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -u root -e "UPDATE mysql.user SET host='%' WHERE user='root' and host='localhost'; FLUSH PRIVILEGES;"
            mysql -u root -e "GRANT USAGE ON *.* to #{get_config('mysql-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-galera-password')}';"
            mysql -u root -e "GRANT ALL PRIVILEGES on *.* TO #{get_config('mysql-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-galera-password')}';"
            mysql -u root -e "GRANT PROCESS ON *.* to '#{get_config('mysql-check-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-check-password')}';"
            mysql -u root -e "FLUSH PRIVILEGES;"
        ]
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT user from mysql.user where User=\"haproxy\"' >/dev/null" }
end

include_recipe "bcpc::mysql-common"

template "/etc/mysql/debian.cnf" do
    source "my-debian.cnf.erb"
    mode 00644
    variables(
        :root_user_key => "mysql-root-user",
        :root_pass_key => "mysql-root-password"
    )
    notifies :reload, "service[mysql]", :immediately
end

file '/etc/mysql/conf.d/wsrep.cnf' do
    action :delete
end

template "/etc/mysql/conf.d/bcc.cnf" do
    source "mysql-bcc.cnf.erb"
    mode 00644
    variables(
      lazy {
        {
          :max_connections => get_mysql_max_connections,
          :innodb_buffer_pool_size => node['bcpc']['mysql-head']['innodb_buffer_pool_size'],
          :innodb_buffer_pool_instances => node['bcpc']['mysql-head']['innodb_buffer_pool_instances'],
          :thread_cache_size => node['bcpc']['mysql-head']['thread_cache_size'],
          :innodb_io_capacity => node['bcpc']['mysql-head']['innodb_io_capacity'],
          :innodb_log_buffer_size => node['bcpc']['mysql-head']['innodb_log_buffer_size'],
          :innodb_flush_method => node['bcpc']['mysql-head']['innodb_flush_method'],
          :max_heap_table_size => node['bcpc']['mysql-head']['max_heap_table_size'],
          :join_buffer_size => node['bcpc']['mysql-head']['join_buffer_size'],
          :sort_buffer_size => node['bcpc']['mysql-head']['sort_buffer_size'],
          :tmp_table_size => node['bcpc']['mysql-head']['tmp_table_size'],
          :slow_query_log => node['bcpc']['mysql-head']['slow_query_log'],
          :slow_query_log_file => node['bcpc']['mysql-head']['slow_query_log_file'],
          :long_query_time => node['bcpc']['mysql-head']['long_query_time'],
          :log_queries_not_using_indexes => node['bcpc']['mysql-head']['log_queries_not_using_indexes'],
          :servers => get_head_nodes,
          :wsrep_cluster_name => node['bcpc']['region_name'],
          :wsrep_port => 4567,
          :galera_user_key => "mysql-galera-user",
          :galera_pass_key => "mysql-galera-password",
          :wsrep_slave_threads => node['bcpc']['mysql-head']['wsrep_slave_threads']
        }
      }
    )
    notifies :restart, "service[mysql]", :immediately
end

# logrotate_app resource is not used because it does not support lazy {}
template '/etc/logrotate.d/mysql_slow_query' do
  source 'logrotate_mysql_slow_query.erb'
  mode   '00400'
  variables(
    lazy {
      {
        :slow_query_log_file => node['bcpc']['mysql-head']['slow_query_log_file'],
        :mysql_root_password => get_config('mysql-root-password'),
        :mysql_root_user     => get_config('mysql-root-user')
      }
    }
  )
end

template '/root/.my.cnf' do
  source 'mysql-shell.my.cnf.erb'
  mode   00600
  owner  'root'
  group  'root'
  sensitive true
  variables(
    lazy {
      {
        :host         => node['bcpc']['management']['vip'],
        :user_key     => 'mysql-root-user',
        :password_key => 'mysql-root-password'
      }
    }
  )
end


# vifs-cleanup cron job removed (replaced by db_cleanup below)
cron 'vifs-cleanup-daily' do
  action :delete
end

db_cleanup_script = '/usr/local/bin/db_cleanup.sh'
cookbook_file db_cleanup_script do
  source 'db_cleanup.sh'
  mode   '00755'
  owner  'root'
  group  'root'
end

cron 'db-cleanup-daily' do
  home    '/root'
  user    'root'
  minute  '0'
  hour    '3'
  command "/usr/local/bin/if_vip #{db_cleanup_script}"
end

template '/usr/local/bin/mysql_slow_query_check.sh' do
  source 'mysql_slow_query_check.sh.erb'
  mode  '00755'
  owner 'root'
  group 'root'
  variables(
    slow_query_log_file: node['bcpc']['mysql-head']['slow_query_log_file']
  )
end
