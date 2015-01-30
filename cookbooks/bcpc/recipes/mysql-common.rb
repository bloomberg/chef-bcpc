#
# Cookbook Name:: bcpc
# Recipe:: mysql-common
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

directory "/etc/mysql/conf.d" do
    owner "root"
    group "root"
    mode 00755
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

package "phpmyadmin" do
    action :upgrade
end

bash "phpmyadmin-config-setup" do
    user "root"
    code <<-EOH
        echo '$cfg["AllowArbitraryServer"] = TRUE;' >> /etc/phpmyadmin/config.inc.php
    EOH
    not_if "cat /etc/phpmyadmin/config.inc.php | grep AllowArbitraryServer"
    notifies :restart, "service[apache2]", :delayed
end
