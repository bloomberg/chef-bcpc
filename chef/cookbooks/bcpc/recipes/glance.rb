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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

glance_db = node['bcpc']['dbname']['glance']
glance_db_user = make_config('glance-db-user', 'glance')
glance_db_password = make_config('glance-db-password', secure_password())

glance_os_user = make_config('glance-os-user', 'glance')
glance_os_password = make_config('glance-os-password', secure_password())

%w(glance glance-api glance-registry).each do |pkg|
  package pkg do
    action :install
  end
end

# hash used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['glance']['db']['dbname'],
  'username' => config['glance']['creds']['db']['username'],
  'password' => config['glance']['creds']['db']['password'],
}

# hash used for openstack access
#
openstack = {
  'username' => config['glance']['creds']['os']['username'],
  'password' => config['glance']['creds']['os']['password'],
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
}

# create client.glance ceph user and keyring starts
#
execute 'get or create client.glance user/keyring' do
  command <<-DOC
    ceph auth get-or-create client.glance \
      mon 'allow r' \
      osd 'allow class-read object_prefix rbd_children, \
           allow rwx pool=images' \
      -o /etc/ceph/ceph.client.glance.keyring
  DOC
  creates '/etc/ceph/ceph.client.glance.keyring'
end
#
# create client.glance ceph user and keyring ends

# create/configure glance openstack user starts
#
execute 'create the glance user' do
  environment os_adminrc

  command <<-DOC
    openstack user create \
      --domain default \
      --password #{openstack['password']} \
      #{openstack['username']}
  DOC

  not_if "openstack user show --domain default #{openstack['username']}"
end

execute 'add admin role to the glance user' do
  environment os_adminrc

  command <<-DOC
    openstack role add \
      --project #{openstack['project']} \
      --user #{openstack['username']} \
      #{openstack['role']}
  DOC

  not_if <<-DOC
    openstack role assignment list \
      --role #{openstack['role']} \
      --user #{openstack['username']} \
      --project #{openstack['project']} \
      --names | grep #{openstack['username']}
  DOC
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
    environment os_adminrc

    name = service['name']
    desc = service['description']

    command <<-DOC
      openstack service create \
        --name "#{name}" --description "#{desc}" #{type}
    DOC

    not_if "openstack service list | grep #{type}"
  end

  %w(admin internal public).each do |uri|
    url = generate_service_catalog_uri(service, uri)

    execute "create the #{project} #{type} #{uri} endpoint" do
      environment os_adminrc

      command <<-DOC
        openstack endpoint create \
          --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if "openstack endpoint list \
        | grep #{type} | grep #{uri}
      "
    end
  end
end
#
# create image service and endpoints ends

# glance package installation and service definition starts
#
package 'glance'
package 'qemu-utils'
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
    'db' => database
  )
  notifies :run, 'execute[create glance database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create glance database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

  command "mysql -u #{mysqladmin['username']} < /tmp/glance-create-db.sql"

  notifies :delete, 'file[/tmp/glance-create-db.sql]', :immediately
  notifies :create, 'template[/etc/glance/glance-api.conf]', :immediately
  notifies :run, 'execute[glance-manage db_sync]', :immediately
end

execute 'glance-manage db_sync' do
  action :nothing
  command <<-DOC
    su -s /bin/sh -c 'glance-manage db_sync' glance
  DOC
end
#
# create/manage glance database ends

# install and configure components starts
#
template '/etc/glance/glance-api.conf' do
  source 'glance/glance-api.conf.erb'
  variables(
    db: database,
    os: openstack,
    config: config,
    headnodes: headnodes(all: true)
  )
  notifies :restart, 'service[glance-api]', :immediately
end
#
# install and configure components ends

execute 'wait for glance to come online' do
  environment os_adminrc
  retries 15
  command 'openstack image list'
end

# create ceph rbd pool starts
#
bash 'create ceph pool' do
  pool = node['bcpc']['glance']['ceph']['pool']['name']

  code <<-DOC
    ceph osd pool create #{pool} 128 128
    ceph osd pool application enable #{pool} rbd
  DOC

  not_if "ceph osd pool ls | grep -w #{pool}"
end

execute 'set ceph pool size' do
  size = node['bcpc']['glance']['ceph']['pool']['size']
  pool = node['bcpc']['glance']['ceph']['pool']['name']

  command "ceph osd pool set #{pool} size #{size}"
  not_if "ceph osd pool get #{pool} size | grep -w 'size: #{size}'"
end
#
# create ceph rbd volume pools ends

# create/upload cirros image starts
#
cirros = node['bcpc']['glance']['images']['cirros']

remote_file cirros['target'] do
  source cirros['source']
  notifies :run, 'execute[convert cirros image]', :immediately
  not_if 'openstack image list | grep -i cirros', environment: os_adminrc
end

execute 'convert cirros image' do
  action :nothing

  command <<-DOC
    qemu-img convert -f qcow2 -O raw \
      #{cirros['target']} \
      #{Chef::Config[:file_cache_path]}/cirros.raw
  DOC

  notifies :run, 'execute[add cirros image]', :immediately
end

execute 'add cirros image' do
  environment os_adminrc
  action :nothing

  command <<-DOC
    openstack image create 'cirros' \
      --public \
      --container-format=bare \
      --disk-format=raw \
      --file #{Chef::Config[:file_cache_path]}/cirros.raw
  DOC
end
#
# create/upload cirros image ends
