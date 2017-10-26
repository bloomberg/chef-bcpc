#
# Cookbook Name:: bcpc
# Recipe:: glance
#
# Copyright 2018, Bloomberg Finance L.P.
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
mysql_root_user     = get_config('mysql-root-user')
mysql_root_password = get_config('mysql-root-password')

glance_db = node['bcpc']['dbname']['glance']
glance_db_user = make_config('glance-db-user', "glance")
glance_db_password = make_config('glance-db-password', secure_password())

glance_os_user = make_config('glance-os-user', "glance")
glance_os_password = make_config('glance-os-password', secure_password())

admin_role = node['bcpc']['keystone']['admin_role']
service_project = node['bcpc']['keystone']['service_project']['name']
region = node['bcpc']['region_name']


# create client.glance ceph user and keyring starts
#
execute 'get or create client.glance user/keyring' do
  command <<-EOH
    ceph auth get-or-create client.glance \
      mon 'allow r' \
      osd 'allow class-read object_prefix rbd_children, \
           allow rwx pool=images' \
      -o /etc/ceph/ceph.client.glance.keyring
  EOH
  creates '/etc/ceph/ceph.client.glance.keyring'
end
#
# create client.glance ceph user and keyring ends


# create/configure glance openstack user starts
#
execute "create the glance user" do
  environment (os_adminrc())

  command <<-EOH
    openstack user create \
      --domain default \
      --password #{glance_os_password} \
      #{glance_os_user}
  EOH

  not_if "openstack user show \
    --domain default #{glance_os_user}
  "
end

execute "add admin role to the glance user" do
  environment (os_adminrc())

  command <<-EOH
    openstack role add \
      --project #{service_project} \
      --user #{glance_os_user} \
      #{admin_role}
  EOH

  not_if "
    openstack role assignment list \
      --role #{admin_role} \
      --user #{glance_os_user} \
      --project #{service_project} \
      --names | grep #{glance_os_user}
  "
end
#
# create/configure glance openstack user ends


# create image service and endpoints starts
#
begin
  type = 'image'
  service = node['bcpc']['catalog'][type]
  project = service['project']

  execute "create the #{project} #{type} service" do
    environment (os_adminrc())

    name = service['name']
    desc = service['description']

    command <<-EOH
      openstack service create \
        --name "#{name}" --description "#{desc}" #{type}
    EOH

    not_if "openstack service list | grep #{type}"
  end

  %w(admin internal public).each{|uri|

    url = generate_service_catalog_uri(service,uri)

    execute "create the #{project} #{type} #{uri} endpoint" do
      environment (os_adminrc())

      command <<-EOH
        openstack endpoint create \
          --region #{region} #{type} #{uri} '#{url}'
      EOH

      not_if "openstack endpoint list \
        | grep #{type} | grep #{uri}
      "
    end
  }
end
#
# create image service and endpoints ends


# glance package installation and service definition starts
#
package 'glance'
package "qemu-utils"

service 'glance-api'
#
# glance package installation and service definition ends


# update file permisssions on ceph.client.glance.keyring to allow the
# glance user to use ceph
#
file '/etc/ceph/ceph.client.glance.keyring' do
  mode '0640'
  owner 'root'
  group 'glance'
end


# create/manage glance database starts
#
file '/tmp/glance-create-db.sql' do
  action :nothing
end

template '/tmp/glance-create-db.sql' do
  source 'glance/glance-create-db.sql.erb'
  variables(
    'glance_db' => glance_db,
    'glance_db_user' => glance_db_user,
    'glance_db_password' => glance_db_password
  )
  notifies :run, 'execute[create glance database]', :immediately
  not_if "mysql -u #{mysql_root_user} \
                -e 'show databases' | grep #{glance_db}",
         :environment => {'MYSQL_PWD' => mysql_root_password}
end

execute 'create glance database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysql_root_password})

  command "mysql -u #{mysql_root_user} < /tmp/glance-create-db.sql"

  notifies :delete, 'file[/tmp/glance-create-db.sql]', :immediately
  notifies :create, 'template[/etc/glance/glance-api.conf]', :immediately
  notifies :run, 'execute[glance-manage db_sync]', :immediately
end

execute 'glance-manage db_sync' do
  action :nothing
  command <<-EOH
    su -s /bin/sh -c "glance-manage db_sync" glance
  EOH
end
#
# create/manage glance database ends

# install and configure components starts
#
template '/etc/glance/glance-api.conf' do
  source 'glance/glance-api.conf.erb'
  variables(
    'servers' => get_head_nodes()
  )
  notifies :restart, 'service[glance-api]', :immediately
end

template "/etc/glance/policy.json" do
  source "glance-policy.json.erb"
  owner 'glance'
  group 'glance'
  mode '0600'

  variables(
    'policy' => JSON.pretty_generate(node['bcpc']['glance']['policy'])
  )
end
#
# install and configure components ends

execute 'wait for glance to come online' do
  environment (os_adminrc())
  retries 15
  command 'openstack image list'
end

images_pool = node['bcpc']['ceph']['images']

bash "create-rados-pool-#{images_pool['name']}" do
  name      = images_pool['name']
  type      = images_pool['type']
  rule      = node['bcpc']['ceph'][type]['rule']
  pg_count  = get_ceph_optimal_pg_count(name)
  pgp_count = pg_count

  code <<-EOH
    ceph osd pool create #{name} #{pg_count} #{pgp_count} #{rule}
    sleep 15
  EOH

  not_if "ceph osd lspools | grep #{name}"
end

bash "set rados-pool-#{images_pool['name']} pool replication" do
  name      = images_pool['name']
  rep_count = get_ceph_replica_count('images')

  code <<-EOH
    ceph osd pool set #{name} size #{rep_count}
  EOH

  not_if "ceph osd pool get #{name} size | grep #{rep_count}"
end


(node['bcpc']['ceph']['pgp_auto_adjust'] ? %w{pg_num pgp_num} : %w{pg_num}).each do |pg|

  name = images_pool['name']

  ruby_block "set-glance-rados-pool-#{pg}" do
    block do
      %x(ceph osd pool set #{name} #{pg} #{get_ceph_optimal_pg_count('images')})
    end
    only_if { %x[ceph osd pool get #{name} #{pg} | awk '{print $2}'].to_i < get_ceph_optimal_pg_count('images') }
  end
end


# create/upload cirros image starts
#
cookbook_file "/tmp/cirros-0.3.4-x86_64-disk.img" do
  source "cirros-0.3.4-x86_64-disk.img"
  cookbook 'bcpc-binary-files'

  notifies :run, 'execute[convert cirros image]', :immediately
  not_if 'openstack image list | grep -i cirros', :environment => os_adminrc()
end

execute 'convert cirros image' do
  action :nothing

  command <<-EOH
    qemu-img convert -f qcow2 -O raw \
      /tmp/cirros-0.3.4-x86_64-disk.img /tmp/cirros-0.3.4-x86_64-disk.raw
  EOH

  notifies :run, 'execute[add cirros image]', :immediately
end

execute "add cirros image" do
  environment (os_adminrc())
  action :nothing

  command <<-EOH
    openstack image create 'Cirros 0.3.4 x86_64' \
      --public --container-format=bare \
      --disk-format=raw --file /tmp/cirros-0.3.4-x86_64-disk.raw
  EOH
end

template "/etc/logrotate.d/glance-common" do
    source "glance/glance-common.logrotate.conf.erb"
    owner "root"
    group "root"
    mode 00644
end
