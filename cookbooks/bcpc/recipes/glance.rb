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
    end
end

package "glance" do
    action :upgrade
end

%w{glance-api glance-registry}.each do |svc|
    service svc do
        action [:enable, :start]
    end
end

service "glance-api" do
    restart_command "service glance-api restart; sleep 5"
end

cookbook_file "/tmp/glance-v2-null-description.patch" do
  source "glance-v2-null-description.patch"
  owner "root"
  mode 0644
end 

bash "patch-backport-for-glance-v2-null-description" do
  user "root"
  code <<-EOH
    cd /usr/lib/python2.7/dist-packages/
    cp glance/schema.py glance/schema.py.prematch
    patch -p1 < /tmp/glance-v2-null-description.patch
    rv=$?
    if [ $rv -ne 0 ]; then
      echo "Error applying patch ($rv) - aborting!"
      exit $rv
    fi
  EOH
  only_if "shasum /usr/lib/python2.7/dist-packages/glance/schema.py | grep -q '^e397f917f21e2067721336c5913e0151ed99bb0c'"
  notifies :restart, "service[glance-api]", :immediately
  notifies :restart, "service[glance-registry]", :immediately
end 

template "/etc/glance/glance-api.conf" do
    source "glance-api.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    variables(:servers => get_head_nodes)
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-registry.conf" do
    source "glance-registry.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-scrubber.conf" do
    source "glance-scrubber.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :restart, "service[glance-api]", :delayed
    notifies :restart, "service[glance-registry]", :delayed
end

template "/etc/glance/glance-cache.conf" do
    source "glance-cache.conf.erb"
    owner "glance"
    group "glance"
    mode 00600
    notifies :restart, "service[glance-api]", :immediately
    notifies :restart, "service[glance-registry]", :immediately
end

template "/etc/glance/policy.json" do
    source "glance-policy.json.erb"
    owner "glance"
    group "glance"
    mode 00600
    variables(:policy => JSON.pretty_generate(node['bcpc']['glance']['policy']))
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

bash "glance-database-sync" do
    action :nothing
    user "root"
    code "glance-manage db_sync"
    notifies :restart, "service[glance-api]", :immediately
    notifies :restart, "service[glance-registry]", :immediately
end

# Note, glance connects to ceph using client.glance, but we have already generated
# the key for that in ceph-head.rb, so by now we should have it in /etc/ceph/ceph.client.glance.key

bash "create-glance-rados-pool" do
    user "root"
    optimal = power_of_2(get_ceph_osd_nodes.length*node['bcpc']['ceph']['pgs_per_node']/node['bcpc']['ceph']['images']['replicas']*node['bcpc']['ceph']['images']['portion']/100)
    code <<-EOH
        ceph osd pool create #{node['bcpc']['ceph']['images']['name']} #{optimal}
        ceph osd pool set #{node['bcpc']['ceph']['images']['name']} crush_ruleset #{(node['bcpc']['ceph']['images']['type']=="ssd") ? node['bcpc']['ceph']['ssd']['ruleset'] : node['bcpc']['ceph']['hdd']['ruleset']}
    EOH
    not_if "rados lspools | grep #{node['bcpc']['ceph']['images']['name']}"
    notifies :run, "bash[wait-for-pgs-creating]", :immediately
end


bash "set-glance-rados-pool-replicas" do
    user "root"
    replicas = [search_nodes("recipe", "ceph-osd").length, node['bcpc']['ceph']['images']['replicas']].min
    if replicas < 1; then
        replicas = 1
    end
    code "ceph osd pool set #{node['bcpc']['ceph']['images']['name']} size #{replicas}"
    not_if "ceph osd pool get #{node['bcpc']['ceph']['images']['name']} size | grep #{replicas}"
end

(node['bcpc']['ceph']['pgp_auto_adjust'] ? %w{pg_num pgp_num} : %w{pg_num}).each do |pg|
    bash "set-glance-rados-pool-#{pg}" do
        user "root"
        optimal = power_of_2(get_ceph_osd_nodes.length*node['bcpc']['ceph']['pgs_per_node']/node['bcpc']['ceph']['images']['replicas']*node['bcpc']['ceph']['images']['portion']/100)
        code "ceph osd pool set #{node['bcpc']['ceph']['images']['name']} #{pg} #{optimal}"
        only_if { %x[ceph osd pool get #{node['bcpc']['ceph']['images']['name']} #{pg} | awk '{print $2}'].to_i < optimal }
        notifies :run, "bash[wait-for-pgs-creating]", :immediately
    end
end

cookbook_file "/tmp/cirros-0.3.4-x86_64-disk.img" do
    source "bins/cirros-0.3.4-x86_64-disk.img"
    owner "root"
    mode 00444
end

package "qemu-utils" do
    action :upgrade
end

bash "glance-cirros-image" do
    user "root"
    code <<-EOH
        . /root/adminrc
        qemu-img convert -f qcow2 -O raw /tmp/cirros-0.3.4-x86_64-disk.img /tmp/cirros-0.3.4-x86_64-disk.raw
        glance image-create --name='Cirros 0.3.4 x86_64' --visibility=public --container-format=bare --disk-format=raw --file /tmp/cirros-0.3.4-x86_64-disk.raw
    EOH
    not_if ". /root/adminrc; glance image-list | grep 'Cirros 0.3.4 x86_64'"
end
