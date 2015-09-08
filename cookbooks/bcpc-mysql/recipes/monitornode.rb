#
# Cookbook Name:: bcpc-mysql
# Recipe:: monitornode
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

include_recipe "bcpc-mysql"

ruby_block "initialize-mysql-monitoring-config" do
    block do
        make_config('mysql-monitoring-root-user', "root")
        make_config('mysql-monitoring-root-password', secure_password)
        make_config('mysql-monitoring-galera-user', "sst")
        make_config('mysql-monitoring-galera-password', secure_password)
        make_config('mysql-check-user', "check")
        make_config('mysql-check-password', secure_password)
    end
end

ruby_block "initial-mysql-monitoring-config" do
    block do
        %x[ mysql -u root -e "DELETE FROM mysql.user WHERE user='';"
            mysql -u root -e "UPDATE mysql.user SET password=PASSWORD('#{get_config('mysql-monitoring-root-password')}') WHERE user='root'; FLUSH PRIVILEGES;"
            export MYSQL_PWD=#{get_config('mysql-monitoring-root-password')};
            mysql -u root -e "UPDATE mysql.user SET host='%' WHERE user='root' and host='localhost'; FLUSH PRIVILEGES;"
            mysql -u root -e "GRANT USAGE ON *.* to #{get_config('mysql-monitoring-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-monitoring-galera-password')}';"
            mysql -u root -e "GRANT ALL PRIVILEGES on *.* TO #{get_config('mysql-monitoring-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-monitoring-galera-password')}';"
            mysql -u root -e "GRANT PROCESS ON *.* to '#{get_config('mysql-check-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-check-password')}';"
            mysql -u root -e "FLUSH PRIVILEGES;"
        ]
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-monitoring-root-password')} mysql -uroot -e 'SELECT user from mysql.user where User=\"haproxy\"' >/dev/null" }
end

template "/etc/mysql/debian.cnf" do
    source "my-debian.cnf.erb"
    mode 00644
    variables(
        :root_user_key => "mysql-monitoring-root-user",
        :root_pass_key => "mysql-monitoring-root-password"
    )
    notifies :restart, "service[mysql]", :delayed
end

template "/etc/mysql/conf.d/wsrep.cnf" do
    source "wsrep.cnf.erb"
    mode 00644
    variables(
      lazy {
        {
          :max_connections         => [get_nodes_with_recipe('bcpc-mysql::monitornode').length*150, 200].max,
          :servers                 => get_nodes_with_recipe('bcpc-mysql::monitornode'),
          :wsrep_cluster_name      => "#{node['bcpc']['region_name']}-Monitoring",
          :wsrep_port              => 4577,
          :galera_user_key         => "mysql-monitoring-galera-user",
          :galera_pass_key         => "mysql-monitoring-galera-password",
          :innodb_buffer_pool_size => node['bcpc']['monitoring']['mysql']['innodb_buffer_pool_size']
        }
      }
    )
    notifies :restart, "service[mysql]", :immediately
end
template "/usr/local/etc/chk_mysql_quorum.sql" do
    source "chk_mysql_quorum.sql.erb"
    mode 0640
    owner "root"
    group "root"
    variables(
      lazy {
        {:min_quorum => get_nodes_with_recipe('bcpc-mysql::monitornode').length/2+1}
      }
    )
end

template "/usr/local/bin/chk_mysql_quorum" do
    source "chk_mysql_quorum.erb"
    mode 0750
    owner "root"
    group "root"
end
