#
# Cookbook Name:: bcpc
# Recipe:: mysql-monitoring
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

include_recipe "bcpc::mysql-packages"

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
        if not system "mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e 'SELECT user from mysql.user where User=\"haproxy\"'" then
            %x[ mysql -u root -e "DELETE FROM mysql.user WHERE user='';"
                mysql -u root -e "UPDATE mysql.user SET password=PASSWORD('#{get_config('mysql-monitoring-root-password')}') WHERE user='root'; FLUSH PRIVILEGES;"
                mysql -u root -p#{get_config('mysql-monitoring-root-password')} -e "UPDATE mysql.user SET host='%' WHERE user='root' and host='localhost'; FLUSH PRIVILEGES;"
                mysql -u root -p#{get_config('mysql-monitoring-root-password')} -e "GRANT USAGE ON *.* to #{get_config('mysql-monitoring-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-monitoring-galera-password')}';"
                mysql -u root -p#{get_config('mysql-monitoring-root-password')} -e "GRANT ALL PRIVILEGES on *.* TO #{get_config('mysql-monitoring-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-monitoring-galera-password')}';"
                mysql -u root -p#{get_config('mysql-monitoring-root-password')} -e "GRANT PROCESS ON *.* to '#{get_config('mysql-check-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-check-password')}';"
                mysql -u root -p#{get_config('mysql-monitoring-root-password')} -e "FLUSH PRIVILEGES;"
            ]
        end
    end
end

db_user = get_config('mysql-monitoring-root-user')
db_password = get_config('mysql-monitoring-root-password')

include_recipe "bcpc::mysql-common"

template "/etc/mysql/debian.cnf" do
    source "my-debian.cnf.erb"
    mode 00644
    variables(
        :db_user => "#{db_user}",
        :db_password => "#{db_password}"
    )
    notifies :restart, "service[mysql]", :delayed
end

template "/etc/mysql/conf.d/wsrep.cnf" do
    source "wsrep.cnf.erb"
    mode 00644
    variables(
        :max_connections => [search_nodes("role", "BCPC-Monitoring").length*50+get_all_nodes.length*5, 200].max,
        :servers => search_nodes("role", "BCPC-Monitoring"),
        :wsrep_cluster_name => "#{node['bcpc']['region_name']}-Monitoring",
        :wsrep_port => 4577,
        :wsrep_user => get_config('mysql-monitoring-galera-user'),
        :wsrep_password => get_config('mysql-monitoring-galera-password')
    )
    notifies :restart, "service[mysql]", :immediately
end

ruby_block "phpmyadmin-debconf-setup" do
    block do
        if not system "debconf-get-selections | grep phpmyadmin >/dev/null 2>&1" then
            puts %x[
                echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/mysql/admin-pass password #{get_config('mysql-monitoring-root-password')}' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/mysql/app-pass password #{get_config('mysql-monitoring-phpmyadmin-password')}' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
            ]
        end
    end
end
