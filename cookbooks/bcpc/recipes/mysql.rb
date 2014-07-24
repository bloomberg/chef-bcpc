#
# Cookbook Name:: bcpc
# Recipe:: mysql
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

include_recipe "bcpc::default"

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

apt_repository "percona" do
    uri node['bcpc']['repos']['mysql']
    distribution node['lsb']['codename']
    components ["main"]
    key "percona-release.key"
end

package "percona-xtradb-cluster-server" do
    action :upgrade
end

bash "initial-mysql-config" do
    code <<-EOH
         mysql -u root -e "DROP USER ''@'localhost';
                           UPDATE mysql.user SET password=PASSWORD('#{get_config('mysql-root-password')}') WHERE user='root';
                           UPDATE mysql.user SET host='%' WHERE user='root' and host='localhost';
                           GRANT USAGE ON *.* to #{get_config('mysql-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-galera-password')}';
                           GRANT ALL PRIVILEGES on *.* TO #{get_config('mysql-galera-user')}@'%' IDENTIFIED BY '#{get_config('mysql-galera-password')}';
                           GRANT PROCESS ON *.* to '#{get_config('mysql-check-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-check-password')}';
                           FLUSH PRIVILEGES;"
         EOH
    only_if "mysql -u root -e 'SELECT COUNT(*) FROM mysql.user'"
end

directory "/etc/mysql" do
    owner "root"
    group "root"
    mode 00755
end

template "/etc/mysql/my.cnf" do
    source "my.cnf.erb"
    mode 00644
    notifies :restart, "service[mysql]", :delayed
end

template "/etc/mysql/debian.cnf" do
    source "my-debian.cnf.erb"
    mode 00644
    notifies :restart, "service[mysql]", :delayed
end

directory "/etc/mysql/conf.d" do
    owner "root"
    group "root"
    mode 00755
end

template "/etc/mysql/conf.d/wsrep.cnf" do
    source "wsrep.cnf.erb"
    mode 00644
    notifies :restart, "service[mysql]", :immediately
    results = get_head_nodes
    # If we are the first one, special case
    seed = ""
    if ((results.length == 1) && (results[0]['hostname'] == node['hostname'])) then
        seed = "gcomm://"
        # Commented out to prevent mysql from always restarting when 1 head-node
        notifies :run, "bash[remove-bare-gcomm]", :delayed
    end
    variables(
        :seed => seed,
        :max_connections => [get_head_nodes.length*50+get_all_nodes.length*5, 200].max,
        :servers => results
    )
end

bash "remove-bare-gcomm" do
    action :nothing
    user "root"
    code <<-EOH
        sed --in-place 's/^\\(wsrep_urls=.*\\),gcomm:\\/\\/"/\\1"/' /etc/mysql/conf.d/wsrep.cnf
    EOH
end

service "mysql" do
    action [:enable, :start]
    start_command "service mysql start || true"
end

package "xinetd" do
    action :upgrade
end

bash "add-mysqlchk-to-etc-services" do
    user "root"
    code <<-EOH
        printf "mysqlchk\t3307/tcp\n" >> /etc/services
    EOH
    not_if "grep mysqlchk /etc/services"
end

template "/etc/xinetd.d/mysqlchk" do
    source "xinetd-mysqlchk.erb"
    owner "root"
    group "root"
    mode 00440
    notifies :restart, "service[xinetd]", :immediately
end

service "xinetd" do
    action [:enable, :start]
end

package "debconf-utils"

ruby_block "phpmyadmin-debconf-setup" do
    block do
        if not system "debconf-get-selections | grep phpmyadmin >/dev/null 2>&1" then
            puts %x[
                echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/mysql/admin-pass password #{get_config('mysql-root-password')}' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/mysql/app-pass password #{get_config('mysql-phpmyadmin-password')}' | debconf-set-selections
                echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
            ]
        end
    end
end

package "phpmyadmin" do
    action :upgrade
end

bash "phpmyadmin-config-setup" do
    user "root"
    code <<-EOH
        echo '$cfg["AllowArbitraryServer"] = TRUE;' >> /etc/phpmyadmin/config.inc.php
    EOH
    not_if "cat /etc/phpmyadmin/config.inc.php | grep AllowArbitraryServer"
end

template "/etc/apache2/vhost-ssl-root.d/phpmyadmin.conf" do
    source "apache-vhost-ssl-root-phpmyadmin.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end
