#
# Cookbook Name:: bcpc
# Recipe:: cinder
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
include_recipe "bcpc::ceph-head"
include_recipe "bcpc::openstack"

ruby_block "initialize-cinder-config" do
    block do
        make_config('mysql-cinder-user', "cinder")
        make_config('mysql-cinder-password', secure_password)
        make_config('keystone-cinder-password', secure_password)
        make_config('libvirt-secret-uuid', %x[uuidgen -r].strip)
    end
end

# for Mitaka, move pool creation to before Cinder installation
# (Cinder now gets very unhappy if the pools are not present on startup)
node['bcpc']['ceph']['enabled_pools'].each do |type|
    bash "create-cinder-rados-pool-#{type}" do
        user "root"
        optimal = power_of_2(get_ceph_osd_nodes.length*node['bcpc']['ceph']['pgs_per_node']/node['bcpc']['ceph']['volumes']['replicas']*node['bcpc']['ceph']['volumes']['portion']/100/node['bcpc']['ceph']['enabled_pools'].length)
        code <<-EOH
            ceph osd pool create #{node['bcpc']['ceph']['volumes']['name']}-#{type} #{optimal}
            ceph osd pool set #{node['bcpc']['ceph']['volumes']['name']}-#{type} crush_ruleset #{(type=="ssd") ? node['bcpc']['ceph']['ssd']['ruleset'] : node['bcpc']['ceph']['hdd']['ruleset']}
        EOH
        not_if "rados lspools | grep #{node['bcpc']['ceph']['volumes']['name']}-#{type}"
        notifies :run, "bash[wait-for-pgs-creating]", :immediately
    end

    bash "set-cinder-rados-pool-replicas-#{type}" do
        user "root"
        replicas = [search_nodes("recipe", "ceph-osd").length, node['bcpc']['ceph']['volumes']['replicas']].min
        if replicas < 1; then
            replicas = 1
        end
        code "ceph osd pool set #{node['bcpc']['ceph']['volumes']['name']}-#{type} size #{replicas}"
        not_if "ceph osd pool get #{node['bcpc']['ceph']['volumes']['name']}-#{type} size | grep #{replicas}"
    end

    (node['bcpc']['ceph']['pgp_auto_adjust'] ? %w{pg_num pgp_num} : %w{pg_num}).each do |pg|
        bash "set-cinder-rados-pool-#{pg}-#{type}" do
            user "root"
            optimal = power_of_2(get_ceph_osd_nodes.length*node['bcpc']['ceph']['pgs_per_node']/node['bcpc']['ceph']['volumes']['replicas']*node['bcpc']['ceph']['volumes']['portion']/100/node['bcpc']['ceph']['enabled_pools'].length)
            code "ceph osd pool set #{node['bcpc']['ceph']['volumes']['name']}-#{type} #{pg} #{optimal}"
            only_if { %x[ceph osd pool get #{node['bcpc']['ceph']['volumes']['name']}-#{type} #{pg} | awk '{print $2}'].to_i < optimal }
            notifies :run, "bash[wait-for-pgs-creating]", :immediately
        end
    end
end

package 'cinder-common' do
  action :upgrade
end

%w{cinder-api cinder-volume cinder-scheduler}.each do |pkg|
  package pkg do
    action :upgrade
  end

  service pkg do
    action [:enable, :start]
  end
end

service "cinder-api" do
    restart_command "service cinder-api restart; sleep 5"
end

template "/etc/cinder/cinder.conf" do
    source "cinder/cinder.conf.erb"
    owner "cinder"
    group "cinder"
    mode "0600"
    variables(
      lazy {
        {
          :servers => get_head_nodes,
          :partials => {
            "keystone/keystone_authtoken.snippet.erb" => {
              "variables" => {
                username: node['bcpc']['cinder']['user'],
                password: get_config('keystone-cinder-password')
              }
            }
          }
        }
      }
    )
    notifies :restart, "service[cinder-api]", :immediately
    notifies :restart, "service[cinder-volume]", :immediately
    notifies :restart, "service[cinder-scheduler]", :immediately
end

template "/etc/cinder/policy.json" do
    source "cinder-policy.json.erb"
    owner "cinder"
    group "cinder"
    mode 00600
    variables(:policy => JSON.pretty_generate(node['bcpc']['cinder']['policy']))
end

ruby_block "cinder-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['cinder']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['cinder']}.* TO '#{get_config('mysql-cinder-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['cinder']}.* TO '#{get_config('mysql-cinder-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-cinder-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[cinder-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['cinder']}\"'|grep \"#{node['bcpc']['dbname']['cinder']}\" >/dev/null" }
end

ruby_block 'update-cinder-db-schema-for-upgrade' do
  block do
    self.notifies :run, "bash[cinder-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if { ::File.exist?('/usr/local/etc/openstack_upgrade') }
end

bash "cinder-database-sync" do
    action :nothing
    user "root"
    code "cinder-manage db sync"
    notifies :restart, "service[cinder-api]", :immediately
    notifies :restart, "service[cinder-volume]", :immediately
    notifies :restart, "service[cinder-scheduler]", :immediately
end

# Configure the glance keystone bits
# https://docs.openstack.org/mitaka/install-guide-ubuntu/glance-install.html
domain = node['bcpc']['keystone']['service_project']['domain']
cinder_username = node['bcpc']['cinder']['user']
cinder_project_name = node['bcpc']['keystone']['service_project']['name']
admin_role_name = node['bcpc']['keystone']['admin_role']

ruby_block "keystone-create-cinder-user" do
  block do
    execute_in_keystone_admin_context("openstack user create --domain #{domain} --password #{get_config('keystone-cinder-password')} #{cinder_username}")
  end
  not_if { execute_in_keystone_admin_context("openstack user show --domain #{domain} #{cinder_username}") ; $?.success? }
end

ruby_block "keystone-assign-cinder-admin-role" do
  block do
    execute_in_keystone_admin_context("openstack role add --project-domain #{domain} --user-domain #{domain} --project #{cinder_project_name} --user #{cinder_username} #{admin_role_name}")
  end
  # NOTE(kmidzi): below command always returns, so check for valid json output; break pattern with only_if
  only_if {
    begin
      r = JSON.parse execute_in_keystone_admin_context("openstack role assignment list --role #{admin_role_name} --project-domain #{domain} --user-domain #{domain} --project #{cinder_project_name} --user #{cinder_username} -fjson")
      r.empty?
    rescue JSON::ParserError
      true
    end
  }
end

# Write out cinder openrc
template "/root/cinder-openrc" do
    source "keystone/openrc.erb"
    owner cinder_username
    group cinder_username
    mode "0600"
    variables(
      lazy {
        {
          username: cinder_username,
          password: get_config('keystone-cinder-password'),
          project_name: cinder_project_name,
          domain: domain
        }
      }
    )
end

# this is a synchronization resource that polls Cinder until it stops returning 503s
bash "wait-for-cinder-to-become-operational" do
    code ". /root/cinder-openrc; until cinder list >/dev/null 2>&1; do sleep 1; done"
    timeout 120
end

node['bcpc']['ceph']['enabled_pools'].each do |type|
    bash "cinder-make-type-#{type}" do
        user "root"
        code <<-EOH
            . /root/cinder-openrc
            cinder type-create #{type.upcase}
            cinder type-key #{type.upcase} set volume_backend_name=#{type.upcase}
        EOH
        not_if ". /root/cinder-openrc; cinder type-list | grep #{type.upcase}"
    end
end

node['bcpc']['cinder']['quota'].each do |k, v|
  bash "cinder-set-default-#{k}-quota" do
    user "root"
    code <<-EOH
      . /root/cinder-openrc
      cinder quota-class-update --#{k} #{v} default
    EOH
  end
end

service "tgt" do
    action [:stop, :disable]
end
