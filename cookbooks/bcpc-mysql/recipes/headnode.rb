#
# Cookbook Name:: bcpc-mysql
# Recipe:: headnode
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

include_recipe 'bcpc-mysql'

ruby_block "initialize-mysql-config" do
    block do
        make_config('mysql-root-user', "root")
        make_config('mysql-root-password', secure_password)
        make_config('mysql-galera-user', "sst")
        make_config('mysql-galera-password', secure_password)
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

template "/etc/mysql/debian.cnf" do
    source "my-debian.cnf.erb"
    mode 00644
    variables(
        :root_user_key => "mysql-root-user",
        :root_pass_key => "mysql-root-password"
    )
    notifies :reload, "service[mysql]", :immediately
end

ruby_block 'set-max-mysql-connections' do
  block do
    if node['bcpc']['mysql-head']['max_connections'] == 0
      node.override['bcpc']['mysql-head']['max_connections'] = [get_head_nodes.length*150+get_all_nodes.length*10, 200].max
    end
  end
end

template "/etc/mysql/conf.d/wsrep.cnf" do
    source "wsrep.cnf.erb"
    mode 00644
    variables(
      lazy {
        {
          :max_connections    => node['bcpc']['mysql-head']['max_connections'],
          :servers            => get_head_nodes,
          :wsrep_cluster_name => node['bcpc']['region_name'],
          :wsrep_port         => 4567,
          :galera_user_key    => "mysql-galera-user",
          :galera_pass_key    => "mysql-galera-password"
        }
      }
    )
    notifies :restart, "service[mysql]", :immediately
end
