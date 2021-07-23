# Cookbook:: bcpc
# Recipe:: placement
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

# used for database creation and access
#
database = {
  'host' => db_conn['host'],
  'port' => db_conn['port'],
  'dbname' => node['bcpc']['placement']['db']['dbname'],
  'username' => config['placement']['creds']['db']['username'],
  'password' => config['placement']['creds']['db']['password'],
}

# placement openstack access
#
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['placement']['creds']['os']['username'],
  'password' => config['placement']['creds']['os']['password'],
}

# create placement user starts
#
execute 'create openstack placement user' do
  environment os_adminrc

  command <<-DOC
    openstack user create #{openstack['username']} \
      --domain #{openstack['domain']} \
      --password #{openstack['password']}
  DOC

  not_if "openstack user show #{openstack['username']} --domain default"
end

execute 'add admin role to placement user' do
  environment os_adminrc

  command <<-DOC
    openstack role add #{openstack['role']} \
      --project #{openstack['project']} \
      --user #{openstack['username']}
  DOC

  not_if <<-DOC
    openstack role assignment list \
      --names \
      --role #{openstack['role']} \
      --project #{openstack['project']} \
      --user #{openstack['username']} | grep #{openstack['username']}
  DOC
end
#
# create placement user ends

ruby_block 'collect openstack service and endpoints list' do
  block do
    node.run_state['os_endpoints'] = openstack_endpoints()
    node.run_state['os_services'] = openstack_services()
  end
  action :run
end

# create placement service and endpoints starts
#
begin
  type = 'placement'
  service = node['bcpc']['catalog'][type]
  name = service['name']

  execute "create the #{name} #{type} service" do
    environment os_adminrc

    desc = service['description']

    command <<-DOC
      openstack service create \
        --name "#{name}" --description "#{desc}" #{type}
    DOC

    not_if { node.run_state['os_services'].include? type }
  end

  %w(admin internal public).each do |uri|
    url = generate_service_catalog_uri(service, uri)

    execute "create the #{name} #{type} #{uri} endpoint" do
      environment os_adminrc

      command <<-DOC
        openstack endpoint create \
          --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if { node.run_state['os_endpoints'].fetch(type, []).include? uri }
    end
  end
end
#
# create placement service and endpoints ends
#
# placement openstack access ends

# install haproxy fragment
template '/etc/haproxy/haproxy.d/placement.cfg' do
  source 'placement/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-placement]', :immediately
end

# placement package installation and service defintiion
package 'placement-api'
service 'placement-api' do
  service_name 'apache2'
end

service 'haproxy-placement' do
  service_name 'haproxy'
end

# create policy.d dir for policy overrides
directory '/etc/placement/policy.d' do
  action :create
end

# TODO: @tstachecki: differs from /etc/placement/placement.conf?
placement_processes = if !node['bcpc']['placement']['workers'].nil?
                        node['bcpc']['placement']['workers']
                      else
                        node['bcpc']['openstack']['services']['workers']
                      end

template '/etc/apache2/sites-available/placement-api.conf' do
  source 'placement/placement-api.conf.erb'
  mode '0640'
  owner 'root'
  group 'placement'

  variables(
    processes: placement_processes
  )
  notifies :run, 'execute[enable placement-api]', :immediately
  notifies :restart, 'service[placement-api]', :immediately
end

execute 'enable placement-api' do
  command 'a2ensite placement-api'
  not_if 'a2query -s placement-api'
end
#
# configure placement ends

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

# create/manage placement databases starts
#
file '/tmp/placement-create-db.sql' do
  action :nothing
end

template '/tmp/placement-create-db.sql' do
  source 'placement/placement-create-db.sql.erb'

  variables(
    db: database
  )

  notifies :run, 'execute[create placement databases]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create placement databases' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

  command "mysql -u #{mysqladmin['username']} < /tmp/placement-create-db.sql"

  notifies :delete, 'file[/tmp/placement-create-db.sql]', :immediately
  notifies :create, 'template[/etc/placement/placement.conf]', :immediately
  notifies :run, 'execute[placement-manage db sync]', :immediately
  notifies :restart, 'service[placement-api]', :immediately
end

execute 'placement-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'placement-manage db sync' placement"
end
#
# create/manage placement databases ends

# configure placement starts
#
template '/etc/placement/placement.conf' do
  source 'placement/placement.conf.erb'
  mode '0640'
  owner 'root'
  group 'placement'

  variables(
    db: database,
    os: openstack,
    config: config,
    is_headnode: headnode?,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )

  notifies :restart, 'service[placement-api]', :immediately
end

# We really want to run something like 'osc resource class list'
# and poll for placement, but that requires python3-osc-placement,
# which is not available in Bionic.  Since apache2 is restarting,
# just query keystone in its place.
execute 'wait for placement to come online' do
  environment os_adminrc
  retries 15
  command 'openstack catalog list'
end
