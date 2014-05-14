#
# Cookbook Name:: bcpc
# Recipe:: horizon
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

include_recipe "bcpc::mysql"
include_recipe "bcpc::openstack"
include_recipe "bcpc::apache2"
include_recipe "bcpc::cobalt"

ruby_block "initialize-horizon-config" do
    block do
        make_config('mysql-horizon-user', "horizon")
        make_config('mysql-horizon-password', secure_password)
    end
end

package "openstack-dashboard" do
    action :upgrade
end

if not node["bcpc"]["vms_key"].nil?
    package "cobalt-horizon" do
        action :upgrade
        options "-o APT::Install-Recommends=0 -o Dpkg::Options::='--force-confnew'"
    end
end

package "openstack-dashboard-ubuntu-theme" do
    action :remove
end

file "/etc/apache2/conf.d/openstack-dashboard.conf" do
    action :delete
end

template "/etc/apache2/vhost-ssl-root.d/openstack-dashboard.conf" do
    source "apache-vhost-ssl-root-openstack-dashboard.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/apache2/sites-available/openstack-dashboard" do
    source "apache-openstack-dashboard.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

bash "apache-enable-openstack-dashboard" do
    user "root"
    code "a2ensite openstack-dashboard"
    not_if "test -r /etc/apache2/sites-enabled/openstack-dashboard"
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/openstack-dashboard/local_settings.py" do
    source "horizon.local_settings.py.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

ruby_block "horizon-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['horizon_dbname']}\"'|grep \"#{node['bcpc']['horizon_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['horizon_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['horizon_dbname']}.* TO '#{get_config('mysql-horizon-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-horizon-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['horizon_dbname']}.* TO '#{get_config('mysql-horizon-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-horizon-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[horizon-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "horizon-database-sync" do
    action :nothing
    user "root"
    code "/usr/share/openstack-dashboard/manage.py syncdb --noinput"
    notifies :restart, "service[apache2]", :immediately
end
