#
# Cookbook Name:: bcpc
# Recipe:: heat
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

include_recipe "bcpc::mysql-head"
include_recipe "bcpc::openstack"

if node['bcpc']['enabled']['heat']
  ruby_block "initialize-heat-config" do
      block do
          make_config('mysql-heat-user', "heat")
          make_config('mysql-heat-password', secure_password)
      end
  end

  %w{heat-common heat-api heat-api-cfn heat-engine}.each do |pkg|
    package pkg do
      action :install
    end
  end

  %w{heat-api heat-api-cfn heat-engine}.each do |svc|
    service svc do
      action [:enable, :start]
    end
  end

  service "heat-api" do
      restart_command "service heat-api restart; sleep 5"
  end

  template "/etc/heat/heat.conf" do
      source "heat.conf.erb"
      owner "heat"
      group "heat"
      mode 00600
      variables(
        lazy {
          {
            :servers => get_head_nodes
          }
        }
      )
      notifies :restart, "service[heat-api]", :delayed
      notifies :restart, "service[heat-api-cfn]", :delayed
      notifies :restart, "service[heat-engine]", :delayed
  end

  template "/etc/heat/policy.json" do
      source "heat-policy.json.erb"
      owner "heat"
      group "heat"
      mode 00600
      variables(:policy => JSON.pretty_generate(node['bcpc']['heat']['policy']))
  end

  directory "/etc/heat/environment.d" do
      user "heat"
      group "heat"
      mode 00755
  end

  ruby_block "heat-database-creation" do
      block do
          %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
              mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['heat']};"
              mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['heat']}.* TO '#{get_config('mysql-heat-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-heat-password')}';"
              mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['heat']}.* TO '#{get_config('mysql-heat-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-heat-password')}';"
              mysql -uroot -e "FLUSH PRIVILEGES;"
          ]
          self.notifies :run, "bash[heat-database-sync]", :immediately
          self.resolve_notification_references
      end
      not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['heat']}\"'|grep \"#{node['bcpc']['dbname']['heat']}\" >/dev/null" }
  end

  ruby_block 'update-heat-db-schema' do
    block do
      self.notifies :run, "bash[heat-database-sync]", :immediately
      self.resolve_notification_references
    end
    only_if { ::File.exist?('/usr/local/etc/openstack_upgrade') }
  end

  bash "heat-database-sync" do
      action :nothing
      user "root"
      code "heat-manage db_sync"
      notifies :restart, "service[heat-api]", :immediately
      notifies :restart, "service[heat-api-cfn]", :immediately
      notifies :restart, "service[heat-engine]", :immediately
  end
else
  %w{heat-api heat-api-cfn heat-engine}.each do |svc|
    service svc do
      action [:disable, :stop]
      only_if {
        ::File.exist?(::File.join('/etc','init',"#{svc}.conf"))
      }
    end
  end
end
