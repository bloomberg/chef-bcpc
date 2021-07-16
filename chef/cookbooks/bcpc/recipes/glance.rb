# Cookbook:: bcpc
# Recipe:: glance
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

mysqladmin = mysqladmin()
psqladmin = psqladmin()
db_conn = db_conn()

# hash used for database creation and access
#
database = {
  'host' => db_conn['host'],
  'port' => db_conn['port'],
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

ruby_block 'collect openstack service and endpoints list' do
  block do
    Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
    os_command = 'openstack service list --format json'
    os_command_out = shell_out(os_command, env: os_adminrc)
    service_list = JSON.parse(os_command_out.stdout)

    os_command = 'openstack endpoint list --format json'
    os_command_out = shell_out(os_command, env: os_adminrc)
    endpoint_list = JSON.parse(os_command_out.stdout)

    # build a hash of service_type => list of uris
    groups = endpoint_list.group_by { |e| e['Service Type'] }
    endpoints = groups.map { |k, v| [k, v.map { |e| e['Interface'] }] }.to_h

    node.run_state['os_services'] = service_list.map { |s| s['Type'] }
    node.run_state['os_endpoints'] = endpoints
  end
  action :run
end

# create image service and endpoints starts
#
begin
  type = 'image'
  service = node['bcpc']['catalog'][type]
  name = service['name']

  execute "create the #{name} #{type} service" do
    environment os_adminrc

    desc = service['description']

    command <<-DOC
      openstack service create --name "#{name}" --description "#{desc}" #{type}
    DOC

    not_if { node.run_state['os_services'].include? type }
  end

  %w(admin internal public).each do |uri|
    url = generate_service_catalog_uri(service, uri)

    execute "create the #{name} #{type} #{uri} endpoint" do
      environment os_adminrc

      command <<-DOC
        openstack endpoint create --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if { node.run_state['os_endpoints'].fetch(type, []).include? uri }
    end
  end
end
#
# create image service and endpoints ends

# install haproxy fragment
template '/etc/haproxy/haproxy.d/glance.cfg' do
  source 'glance/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-glance]', :immediately
end

# glance package installation and service definition
package %w(
  glance
  qemu-utils
)
service 'glance-api'
service 'haproxy-glance' do
  service_name 'haproxy'
end

directory '/etc/ceph' do
  action :create
end

# create client.glance Ceph user and keyring
template '/etc/ceph/ceph.client.glance.keyring' do
  source 'glance/ceph.client.glance.keyring.erb'

  mode '0640'
  owner 'root'
  group 'glance'

  variables(
    key: config['ceph']['client']['glance']['key']
  )
  notifies :run, 'execute[import glance ceph client key]', :immediately
end

# If this node is an OpenStack headnode and a storage headnode, then this
# recipe is responsible for importing the client.glance Ceph keyring.
execute 'import glance ceph client key' do
  action :nothing
  command 'ceph auth import -i /etc/ceph/ceph.client.glance.keyring'
  only_if { storageheadnode? }
end

# If this node is an OpenStack headnode and a storage headnode, then the
# storage headnode's Ceph recipe is responsible for rendering the Ceph
# configuration file and appending the Glance Ceph user to the list of
# rbd_users.
unless storageheadnode?
  rbd_users = []
  rbd_users.append('glance')

  template '/etc/ceph/ceph.conf' do
    source 'ceph/ceph.conf.erb'

    variables(
      config: config,
      storageheadnodes: storageheadnodes,
      public_network: primary_network_aggregate_cidr,
      rbd_users: rbd_users
    )
    notifies :restart, 'service[glance-api]', :delayed
  end
end

# Ensure the database user is present on ProxySQL
#
bcpc_proxysql_user "create #{database['username']} proxysql user" do
  user database
  psqladmin psqladmin
  only_if { node['bcpc']['proxysql']['enabled'] }
  notifies :run, 'bcpc_proxysql_reload[reload proxysql '\
    "#{database['username']}]", :immediately
end

bcpc_proxysql_reload "reload proxysql #{database['username']}" do
  psqladmin psqladmin
  action :nothing
end
# end ProxySQL user creation

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

# create policy.d dir for policy overrides
directory '/etc/glance/policy.d' do
  action :create
end

# install and configure components starts
#
template '/etc/glance/glance-api.conf' do
  source 'glance/glance-api.conf.erb'
  mode '0640'
  owner 'root'
  group 'glance'

  variables(
    db: database,
    os: openstack,
    config: config,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true)
  )
  notifies :restart, 'service[glance-api]', :immediately
end
#
# install and configure components ends

service 'glance-registry' do
  action [:disable, :stop]
end

execute 'wait for glance to come online' do
  environment os_adminrc
  retries 15
  command 'openstack image list'
end
