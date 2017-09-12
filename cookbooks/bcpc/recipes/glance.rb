#
# Cookbook Name:: bcpc
# Recipe:: glance
#
# Copyright 2015, Bloomberg Finance L.P.
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

ruby_block "initialize-glance-config" do
    block do
        make_config('mysql-glance-user', "glance")
        make_config('mysql-glance-password', secure_password)
        make_config('keystone-glance-password', secure_password)
    end
end

%w{glance glance-api glance-registry}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

%w{glance-api glance-registry}.each do |svc|
    service svc do
        action [:enable, :start]
    end
end

service "glance-api" do
    restart_command "service glance-api restart; sleep 5"
end

# Configure the glance keystone bits
# https://docs.openstack.org/mitaka/install-guide-ubuntu/glance-install.html
domain = node['bcpc']['keystone']['service_project']['domain']
glance_username = 'glance'
glance_project_name = node['bcpc']['keystone']['service_project']['name']
admin_role_name = node['bcpc']['keystone']['admin_role']

ruby_block "keystone-create-glance-user" do
  block do
    execute_in_keystone_admin_context("openstack user create --domain #{domain} --password #{get_config('keystone-glance-password')} #{glance_username}")
  end
  not_if { execute_in_keystone_admin_context("openstack user show --domain #{domain} #{glance_username}") ; $?.success? }
end

ruby_block "keystone-assign-glance-admin-role" do
  block do
    execute_in_keystone_admin_context("openstack role add --project-domain #{domain} --user-domain #{domain} --project #{glance_project_name} --user #{glance_username} #{admin_role_name}")
  end
  # NOTE(kmidzi): below command always returns, so check for valid json output; break pattern with only_if
  only_if {
    begin
      r = JSON.parse execute_in_keystone_admin_context("openstack role assignment list --role #{admin_role_name} --project-domain #{domain} --user-domain #{domain} --project #{glance_project_name} --user #{glance_username} -fjson")
      r.empty?
    rescue JSON::ParserError
      true
    end
  }
end

template "/etc/glance/glance-api.conf" do
    source "glance/glance-api.conf.erb"
    owner glance_username
    group glance_username
    mode "0600"
    variables(
      lazy {
        {
          :servers => get_head_nodes,
          :partials => {
            "keystone/keystone_authtoken.snippet.erb" => {
              "variables" => {
                username: node['bcpc']['glance']['user'],
                password: get_config('keystone-glance-password')
              }
            }
          }
        }
      }
    )
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-registry.conf" do
    source "glance/glance-registry.conf.erb"
    owner glance_username
    group glance_username
    mode "0600"
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-scrubber.conf" do
    source "glance/glance-scrubber.conf.erb"
    owner glance_username
    group glance_username
    mode "0600"
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-cache.conf" do
    source "glance/glance-cache.conf.erb"
    owner glance_username
    group glance_username
    mode "0600"
    notifies :restart, "service[glance-api]", :immediately
    notifies :restart, "service[glance-registry]", :immediately
end

template "/etc/glance/policy.json" do
    source "glance/glance-policy.json.erb"
    owner glance_username
    group glance_username
    mode "0600"
    variables(:policy => JSON.pretty_generate(node['bcpc']['glance']['policy']))
end

# Write out glance openrc
template "/root/glance-openrc" do
    source "keystone/openrc.erb"
    owner glance_username
    group glance_username
    mode "0600"
    variables(
      lazy {
        {
          username: glance_username,
          password: get_config('keystone-glance-password'),
          project_name: glance_project_name,
          domain: domain
        }
      }
    )
end

ruby_block "glance-database-creation" do
    block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['glance']};"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['glance']}.* TO '#{get_config('mysql-glance-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-glance-password')}';"
            mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['glance']}.* TO '#{get_config('mysql-glance-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-glance-password')}';"
            mysql -uroot -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :run, "bash[glance-database-sync]", :immediately
        self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['glance']}\"'|grep \"#{node['bcpc']['dbname']['glance']}\" >/dev/null" }
end

ruby_block 'update-glance-db-schema' do
  block do
    self.notifies :run, "bash[glance-database-sync]", :immediately
    self.resolve_notification_references
  end
  only_if { ::File.exist?('/usr/local/etc/openstack_upgrade') }
end

bash "glance-database-sync" do
    action :nothing
    # TODO(kmidzi): why is this run as root?
    user "root"
    code "glance-manage db_sync"
    notifies :restart, "service[glance-api]", :immediately
    notifies :restart, "service[glance-registry]", :immediately
end

# Note, glance connects to ceph using client.glance, but we have already generated
# the key for that in ceph-head.rb, so by now we should have it in /etc/ceph/ceph.client.glance.key

ruby_block "create-glance-rados-pool" do
  block do
    crush_ruleset = (node['bcpc']['ceph']['images']['type'] == "ssd") ? node['bcpc']['ceph']['ssd']['ruleset'] : node['bcpc']['ceph']['hdd']['ruleset']
    %x(
      ceph osd pool create #{node['bcpc']['ceph']['images']['name']} #{get_ceph_optimal_pg_count('images')};
      ceph osd pool set #{node['bcpc']['ceph']['images']['name']} crush_ruleset #{crush_ruleset}
    )
  end
  not_if "rados lspools | grep #{node['bcpc']['ceph']['images']['name']}"
  notifies :run, "bash[wait-for-pgs-creating]", :immediately
end


ruby_block "set-glance-rados-pool-replicas" do
  block do
    %x(ceph osd pool set #{node['bcpc']['ceph']['images']['name']} size #{get_ceph_replica_count('images')})
  end
  not_if "ceph osd pool get #{node['bcpc']['ceph']['images']['name']} size | grep #{get_ceph_replica_count('images')}"
end

(node['bcpc']['ceph']['pgp_auto_adjust'] ? %w{pg_num pgp_num} : %w{pg_num}).each do |pg|
  ruby_block "set-glance-rados-pool-#{pg}" do
    block do
      %x(ceph osd pool set #{node['bcpc']['ceph']['images']['name']} #{pg} #{get_ceph_optimal_pg_count('images')})
    end
    only_if { %x[ceph osd pool get #{node['bcpc']['ceph']['images']['name']} #{pg} | awk '{print $2}'].to_i < get_ceph_optimal_pg_count('images') }
    notifies :run, "bash[wait-for-pgs-creating]", :immediately
  end
end

cookbook_file "/tmp/cirros-0.3.4-x86_64-disk.img" do
    source "cirros-0.3.4-x86_64-disk.img"
    cookbook 'bcpc-binary-files'
    owner "root"
    mode "0444"
end

package "qemu-utils"

bash "glance-cirros-image" do
    user "root"
    code <<-EOH
        . /root/glance-openrc
        . /root/api_versionsrc
        qemu-img convert -f qcow2 -O raw /tmp/cirros-0.3.4-x86_64-disk.img /tmp/cirros-0.3.4-x86_64-disk.raw
        glance image-create --name='Cirros 0.3.4 x86_64' --visibility=public --container-format=bare --disk-format=raw --file /tmp/cirros-0.3.4-x86_64-disk.raw
    EOH
    not_if ". /root/glance-openrc; glance image-list | grep 'Cirros 0.3.4 x86_64'"
end
