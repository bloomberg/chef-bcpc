#
# Cookbook Name:: bcpc-mysql
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

apt_repository "percona" do
    uri node['bcpc']['repos']['mysql']
    distribution node['lsb']['codename']
    components ["main"]
    key "percona-release.key"
end

include_recipe "bcpc-xinetd"

package "percona-xtradb-cluster-56" do
    action :upgrade
end

directory "/etc/mysql" do
    owner "root"
    group "root"
    mode 00755
end

directory "/etc/mysql/conf.d" do
    owner "root"
    group "root"
    mode 00755
end

template "/etc/mysql/my.cnf" do
    source "my.cnf.erb"
    mode 00644
    notifies :restart, "service[mysql]", :immediately
end

service "mysql" do
    action [:enable]
    supports :status => true, :restart => true, :reload => true
end

bash "add-mysqlchk-to-etc-services" do
    user "root"
    code <<-EOH
        printf "mysqlchk\t3307/tcp\n" >> /etc/services
    EOH
    not_if "getent services mysqlchk/tcp"
end

ruby_block "create-mysql-check-user" do
    block do
        make_config('mysql-check-user', "check")
        make_config('mysql-check-password', secure_password)
    end
end

template "/etc/xinetd.d/mysqlchk" do
    source "xinetd-mysqlchk.erb"
    owner "root"
    group "root"
    mode 00440
    notifies :restart, "service[xinetd]", :immediately
end

package "debconf-utils"
