# Cookbook:: bcpc
# Recipe:: cinder
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
zone_config = ZoneConfig.new(node, region, method(:data_bag_item))
cinder_config = zone_config.cinder_config

mysqladmin = mysqladmin()
psqladmin = psqladmin()
db_conn = db_conn()

# hash used for database creation and access
#
database = {
  'host' => db_conn['host'],
  'port' => db_conn['port'],
  'dbname' => node['bcpc']['cinder']['db']['dbname'],
  'username' => config['cinder']['creds']['db']['username'],
  'password' => config['cinder']['creds']['db']['password'],
}

# hash used for openstack access
#
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['cinder']['creds']['os']['username'],
  'password' => config['cinder']['creds']['os']['password'],
}

# create cinder openstack user starts
execute 'create cinder openstack user' do
  environment os_adminrc

  command <<-DOC
    openstack user create #{openstack['username']} \
      --domain #{openstack['domain']} --password #{openstack['password']}
  DOC

  not_if <<-DOC
    openstack user show #{openstack['username']} --domain #{openstack['domain']}
  DOC
end

execute 'add openstack admin role to cinder user' do
  environment os_adminrc

  command <<-DOC
    openstack role add #{openstack['role']} \
      --project #{openstack['project']} --user #{openstack['username']}
  DOC

  not_if <<-DOC
    openstack role assignment list \
      --names \
      --role #{openstack['role']} \
      --project #{openstack['project']} \
      --user #{openstack['username']} | grep #{openstack['username']}
  DOC
end
# create cinder openstack user ends

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

# create cinder volume services and endpoints starts
begin
  %w(volumev2 volumev3).each do |type|
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

        not_if { node.run_state['os_endpoints'][type].include? uri rescue false }
      end
    end
  end
end
# create cinder volume services and endpoints ends

# install haproxy fragment
template '/etc/haproxy/haproxy.d/cinder.cfg' do
  source 'cinder/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-cinder]', :immediately
end

# cinder package installation and service definition
package ['cinder-scheduler', 'cinder-volume'] do
  action :upgrade
end

service 'cinder-api' do
  service_name 'apache2'
end

service 'cinder-volume' do
  retries 10
  retry_delay 5
end

service 'cinder-scheduler' do
  retries 10
  retry_delay 5
end

service 'haproxy-cinder' do
  service_name 'haproxy'
end

# create policy.d dir for policy overrides
directory '/etc/cinder/policy.d' do
  action :create
end

directory '/etc/ceph' do
  action :create
end

# create client.*cinder Ceph users and keyrings
cinder_config.ceph_clients.each do |client|
  template "/etc/ceph/ceph.client.#{client['client']}.keyring" do
    source 'cinder/ceph.client.cinder.keyring.erb'

    mode '0640'
    owner 'root'
    group 'cinder'

    variables(
      client: client['client'],
      key: client['key'],
      pools: client['pools']
    )
  end

  # If this node is an OpenStack headnode and a storage headnode, then this
  # recipe is responsible for importing the client.*cinder Ceph keyrings.
  execute 'import cinder ceph client key' do
    command \
      "ceph auth import -i /etc/ceph/ceph.client.#{client['client']}.keyring"
    only_if { storageheadnode? }
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

# create/manage cinder database starts
file '/tmp/cinder-db.sql' do
  action :nothing
end

template '/tmp/cinder-db.sql' do
  source 'cinder/cinder-db.sql.erb'

  variables(
    db: database
  )

  notifies :run, 'execute[create cinder database]', :immediately

  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create cinder database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

  command "mysql -u #{mysqladmin['username']} < /tmp/cinder-db.sql"

  notifies :delete, 'file[/tmp/cinder-db.sql]', :immediately
  notifies :create, 'template[/etc/cinder/cinder.conf]', :immediately
  notifies :run, 'execute[cinder-manage db sync]', :immediately
end

execute 'cinder-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'cinder-manage db sync' cinder"
end
# create/manage cinder database ends

execute 'disable old cinder config' do
  command 'a2disconf cinder-wsgi'
  only_if 'a2query -c cinder-wsgi'
end

file '/etc/apache2/conf-available/cinder-wsgi.conf' do
  action :delete
end

# configure cinder service starts
cinder_processes = if !node['bcpc']['cinder']['workers'].nil?
                     node['bcpc']['cinder']['workers']
                   else
                     node['bcpc']['openstack']['services']['workers']
                   end

template '/etc/apache2/sites-available/cinder-api.conf' do
  source 'cinder/cinder-api.conf.erb'
  mode '0640'
  owner 'root'
  group 'cinder'

  variables(
    processes: cinder_processes
  )
  notifies :run, 'execute[enable cinder-api]', :immediately
  notifies :restart, 'service[cinder-api]', :immediately
end

execute 'enable cinder-api' do
  command 'a2ensite cinder-api'
  not_if 'a2query -s cinder-api'
end

template '/etc/cinder/cinder.conf' do
  source 'cinder/cinder.conf.erb'
  mode '0640'
  owner 'root'
  group 'cinder'

  variables(
    db: database,
    backends: cinder_config.backends,
    config: config,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true),
    scheduler_default_filters: cinder_config.filters
  )

  notifies :restart, 'service[cinder-volume]', :immediately
  notifies :restart, 'service[cinder-scheduler]', :immediately
end

# add AccessList filter and update cinder entry_points.txt
if zone_config.enabled?

  cookbook_file '/usr/lib/python3/dist-packages/cinder/scheduler/filters/access_filter.py' do
    source 'cinder/access_filter.py'
  end

  bash 'add AccessList filter to cinder' do
    code <<-EOH
      entry_points_txt=$(dpkg -L python3-cinder | grep entry_points.txt)

      if [ -z ${entry_points_txt} ]; then
        echo "entry_points.txt file path could not be found"
        exit 1
      fi

      if ! grep AccessFilter ${entry_points_txt}; then

        # update entry points file using crudini
        crudini --set ${entry_points_txt} cinder.scheduler.filters \
          AccessFilter cinder.scheduler.filters.access_filter:AccessFilter

        # sleep for a brief moment before restarting cinder-scheduler
        sleep 10

        # restart cinder-scheduler
        systemctl restart cinder-scheduler

      fi
    EOH
  end
end

cookbook_file '/etc/cinder/api-paste.ini' do
  source 'cinder/api-paste.ini'
  mode '0640'
  notifies :restart, 'service[cinder-api]', :immediately
end
# configure cinder service ends

execute 'wait for cinder to come online' do
  environment os_adminrc
  retries 30
  command 'openstack volume service list'
end

ruby_block 'collect openstack volume type list' do
  block do
    Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
    os_command = 'openstack volume type list --long --format json'
    os_command_out = shell_out(os_command, env: os_adminrc)
    vt_list = JSON.parse(os_command_out.stdout)
    node.run_state['os_vol_type_props'] = vt_list.map { |t| [t['Name'], t['Properties']] }.to_h
  end
  action :run
end

cinder_config.backends.each do |backend|
  backend_name = backend['name']
  create_args = []
  create_args.append(backend_name)

  if backend['private']
    create_args.append('--private')
  else
    create_args.append('--public')
  end

  execute "create ceph cinder backend type: #{backend_name}" do
    environment os_adminrc
    retries 3
    command <<-EOH
      openstack volume type create #{create_args.join(' ')}
    EOH
    not_if { node.run_state['os_vol_type_props'].key? backend_name }
  end

  execute "set cinder backend properties for: #{backend_name}" do
    environment os_adminrc
    retries 3
    command <<-DOC
      openstack volume type set #{backend_name} \
        --property volume_backend_name=#{backend_name}
    DOC
    not_if { node.run_state['os_vol_type_props'][backend_name]['volume_backend_name'] == backend_name rescue false }
  end
end

execute 'make sure cinder-volume comes up' do
  action :nothing
  retries 30
  command 'systemctl start cinder-volume'
  not_if 'systemctl status cinder-volume'
end
