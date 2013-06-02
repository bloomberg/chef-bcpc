#
# Cookbook Name:: bcpc
# Recipe:: glance
#
# Copyright 2013, Bloomberg L.P.
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
include_recipe "bcpc::ceph-head"
include_recipe "bcpc::openstack"

ruby_block "initialize-glance-config" do
    block do
        make_config('mysql-glance-user', "glance")
        make_config('mysql-glance-password', secure_password)
    end
end

package "glance" do
    action :upgrade
end

%w{glance-api glance-registry}.each do |svc|
    service svc do
        action [ :enable, :start ]
    end
end

bash "restart-glance" do
    action :nothing
    notifies :restart, "service[glance-api]", :immediately
    notifies :restart, "service[glance-registry]", :immediately
end

template "/etc/glance/glance-api.conf" do
    source "glance-api.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :run, "bash[restart-glance]", :delayed
end

template "/etc/glance/glance-registry.conf" do
    source "glance-registry.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :run, "bash[restart-glance]", :delayed
end

template "/etc/glance/glance-scrubber.conf" do
    source "glance-scrubber.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :run, "bash[restart-glance]", :delayed
end

template "/etc/glance/glance-cache.conf" do
    source "glance-cache.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :run, "bash[restart-glance]", :delayed
end

ruby_block "glance-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['glance_dbname']}\"'|grep \"#{node['bcpc']['glance_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['glance_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['glance_dbname']}.* TO '#{get_config('mysql-glance-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-glance-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['glance_dbname']}.* TO '#{get_config('mysql-glance-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-glance-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[glance-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "glance-database-sync" do
    action :nothing
    user "root"
    code "glance-manage db_sync"
    notifies :run, "bash[restart-glance]", :immediately
end

bash "create-glance-rados-pool" do
    user "root"
    code <<-EOH
        ceph osd pool create #{node[:bcpc][:glance_rbd_pool]} 1000
        ceph osd pool set #{node[:bcpc][:glance_rbd_pool]} size 3
    EOH
    not_if "rados lspools | grep #{node[:bcpc][:glance_rbd_pool]}"
end
