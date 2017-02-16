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

if node['bcpc']['mysql-head']['max_connections'] == 0 then
    node.default['bcpc']['mysql-head']['max_connections'] = [get_head_nodes.length*150+get_all_nodes.length*10, 450].max
end

template "/etc/mysql/conf.d/wsrep.cnf" do
    source "wsrep.cnf.erb"
    mode 00644
    variables(
        :sql_mode => node['bcpc']['mysql-head']['sql_mode'],
        :max_connections => node['bcpc']['mysql-head']['max_connections'],
        :servers => get_head_nodes,
        :wsrep_cluster_name => node['bcpc']['region_name'],
        :wsrep_port => 4567,
        :galera_user_key => "mysql-galera-user",
        :galera_pass_key => "mysql-galera-password",
        :innodb_buffer_pool_size => node['bcpc']['mysql-head']['innodb_buffer_pool_size'],
        :innodb_buffer_pool_instances => node['bcpc']['mysql-head']['innodb_buffer_pool_instances'],
        :thread_cache_size => node['bcpc']['mysql-head']['thread_cache_size'],
        :innodb_io_capacity => node['bcpc']['mysql-head']['innodb_io_capacity'],
        :innodb_log_buffer_size => node['bcpc']['mysql-head']['innodb_log_buffer_size'],
        :innodb_flush_method => node['bcpc']['mysql-head']['innodb_flush_method'],
        :wsrep_slave_threads => node['bcpc']['mysql-head']['wsrep_slave_threads'],
        :slow_query_log => node['bcpc']['mysql-head']['slow_query_log'],
        :slow_query_log_file => node['bcpc']['mysql-head']['slow_query_log_file'],
        :long_query_time => node['bcpc']['mysql-head']['long_query_time'],
        :log_queries_not_using_indexes => node['bcpc']['mysql-head']['log_queries_not_using_indexes']
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


template '/usr/local/bin/mysql_slow_query_check.sh' do
  source 'mysql_slow_query_check.sh.erb'
  mode  '00755'
  owner 'root'
  group 'root'
  variables(
    slow_query_log_file: node['bcpc']['mysql-head']['slow_query_log_file']
  )
end
