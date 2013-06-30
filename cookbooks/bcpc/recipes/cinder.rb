#
# Cookbook Name:: bcpc
# Recipe:: cinder
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

ruby_block "initialize-cinder-config" do
    block do
        make_config('mysql-cinder-user', "cinder")
        make_config('mysql-cinder-password', secure_password)
        make_config('libvirt-secret-uuid', %x[uuidgen -r].strip)
    end
end

%w{cinder-api cinder-volume cinder-scheduler}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [ :enable, :start ]
    end
end

bash "restart-cinder" do
    action :nothing
    notifies :restart, "service[cinder-api]", :immediately
    notifies :restart, "service[cinder-volume]", :immediately
    notifies :restart, "service[cinder-scheduler]", :immediately
end

template "/etc/cinder/cinder.conf" do
    source "cinder.conf.erb"
    owner "cinder"
    group "cinder"
    mode 00600
    variables( :servers => get_head_nodes )
    notifies :run, "bash[restart-cinder]", :delayed
end

template "/etc/cinder/api-paste.ini" do
    source "cinder.api-paste.ini.erb"
    owner "cinder"
    group "cinder"
    mode 00600
    notifies :run, "bash[restart-cinder]", :delayed
end

ruby_block "cinder-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['cinder_dbname']}\"'|grep \"#{node['bcpc']['cinder_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['cinder_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['cinder_dbname']}.* TO '#{get_config('mysql-cinder-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['cinder_dbname']}.* TO '#{get_config('mysql-cinder-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :run, "bash[cinder-database-sync]", :immediately
            self.resolve_notification_references
        end
    end
end

bash "cinder-database-sync" do
    action :nothing
    user "root"
    code "cinder-manage db sync"
    notifies :run, "bash[restart-cinder]", :immediately
end

bash "create-cinder-rados-pool" do
    user "root"
    code <<-EOH
        ceph osd pool create #{node[:bcpc][:cinder_rbd_pool]} 1000
        ceph osd pool set #{node[:bcpc][:cinder_rbd_pool]} size 3
    EOH
    not_if "rados lspools | grep #{node[:bcpc][:cinder_rbd_pool]}"
end

service "tgt" do
    action [ :stop, :disable ]
end
