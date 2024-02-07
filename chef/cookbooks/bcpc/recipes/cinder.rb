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
alternate_backends = cinder_config.alternate_backends

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
    node.run_state['os_endpoints'] = openstack_endpoints()
    node.run_state['os_services'] = openstack_services()
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

        not_if { node.run_state['os_endpoints'].fetch(type, []).include? uri }
      end
    end
  end
end
# create cinder volume services and endpoints ends

# Install *only* the base Cinder scaffolding that creates the role account
# and provides functionality for initializing the database. This gives us
# a window to configure the services and initialize the database prior to
# installing the packages which provide unit files (and thus start) the
# actual Cinder services (cinder-api, cinder-scheduler, cinder-volume).
package %w(
  cinder-common
  python3-cinder
)

# create client.*cinder Ceph users and keyrings
directory '/etc/ceph' do
  action :create
end

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

# create policy.d dir for policy overrides
directory '/etc/cinder/policy.d' do
  action :create
end

# add lightos active/active driver
if zone_config.alternate_backends_enabled?
  cookbook_file '/usr/lib/python3/dist-packages/cinder/volume/drivers/lightos.py' do
    source 'cinder/lightos.py'
    notifies :run, 'execute[py3compile-cinder]', :immediately
    notifies :restart, 'service[cinder-volume]', :delayed
  end

  cookbook_file '/usr/lib/python3/dist-packages/os_brick/initiator/connectors/lightos.py' do
    source 'cinder/lightos_connector.py'
    notifies :run, 'execute[py3compile-os-brick]', :immediately
    notifies :restart, 'service[cinder-volume]', :delayed
  end

  execute 'py3compile-cinder' do
    action :nothing
    command 'py3compile -p python3-cinder'
  end

  execute 'py3compile-os-brick' do
    action :nothing
    command 'py3compile -p python3-os-brick'
  end
end

# add AccessList filter and update cinder entry_points.txt
if zone_config.enabled?
  cookbook_file '/usr/lib/python3/dist-packages/cinder/scheduler/filters/access_filter.py' do
    source 'cinder/access_filter.py'
    notifies :run, 'execute[py3compile-cinder]', :immediately
  end

  execute 'py3compile-cinder' do
    action :nothing
    command 'py3compile -p python3-cinder'
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
      fi
    EOH
  end
end

if !init_cloud? && zone_config.alternate_backends_enabled?
  cinder_internal_tenant_project_id = ''
  internal_project = node['bcpc']['cinder']['alternate_backends']['cinder_internal_tenant_project'] || ''
  ruby_block 'collect Cinder internal project uuid' do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      os_command = "openstack project show #{internal_project} -c id -f value"
      os_command_out = shell_out(os_command, env: os_adminrc)
      if os_command_out.error?
        raise "Unable to find the project id for project name #{internal_project}"
      end
      internal_project_id = os_command_out.stdout.chomp()
      unless internal_project_id.empty?
        cinder_internal_tenant_project_id = internal_project_id
      end
    end
    not_if internal_project.empty?
  end

  cinder_internal_tenant_user_id = ''
  internal_user = node['bcpc']['cinder']['alternate_backends']['cinder_internal_tenant_user'] || ''
  ruby_block 'collect Cinder internal user uuid' do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      os_command = "openstack user show #{internal_user} -c id -f value"
      os_command_out = shell_out(os_command, env: os_adminrc)
      if os_command_out.error?
        raise "Unable to find the user id for user name #{internal_user}"
      end
      internal_user_id = os_command_out.stdout.chomp()
      unless internal_user_id.empty?
        cinder_internal_tenant_user_id = internal_user_id
      end
    end
    not_if internal_user.empty?
  end
end

# lay down cinder configuration files
cookbook_file '/etc/cinder/api-paste.ini' do
  source 'cinder/api-paste.ini'
  mode '0640'
  notifies :restart, 'service[cinder-api]', :delayed
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
    alternate_backends_enabled:  zone_config.alternate_backends_enabled?,
    rmqnodes: rmqnodes(all: true),
    alternate_backends: cinder_config.alternate_backends,
    scheduler_default_filters: cinder_config.filters,
    init_cloud: init_cloud?,
    cinder_internal_tenant_project_id: lazy { cinder_internal_tenant_project_id },
    cinder_internal_tenant_user_id: lazy { cinder_internal_tenant_user_id }
  )

  notifies :restart, 'service[cinder-api]', :delayed
  notifies :restart, 'service[cinder-scheduler]', :delayed
  notifies :restart, 'service[cinder-volume]', :delayed
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
  notifies :run, 'execute[cinder-manage db sync]', :immediately
end

execute 'cinder-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'cinder-manage db sync' cinder"
end
# create/manage cinder database ends

# configure cinder service starts
package 'cinder-api'

execute 'disable old cinder config' do
  command 'a2disconf cinder-wsgi'
  only_if 'a2query -c cinder-wsgi'
end

service 'cinder-api' do
  service_name 'apache2'
end

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

execute 'wait for cinder to come online' do
  environment os_adminrc
  retries 30
  command 'openstack volume service list'
end

package %w(
  cinder-scheduler
  cinder-volume
) do
  action :upgrade
end

service 'cinder-scheduler'
service 'cinder-volume'
# configure cinder service ends

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
  create_args = [].append(backend_name)

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

    not_if { node.run_state['os_vol_type_props'].dig(backend_name, 'volume_backend_name') == backend_name }
  end

  ruby_block "add a qos policy to the volume type #{backend_name}" do
    qos_name = "#{backend_name}-qos"
    block do
      add_qos_to_volume_type(backend)
    end
    only_if { backend['qos_enabled'] }
    not_if <<-DOC
      openstack volume qos show #{qos_name}
    DOC
  end # ruby block

  ruby_block "remove the qos policy from the volume type #{backend_name}" do
    qos_name = "#{backend_name}-qos"
    block do
      remove_qos_from_volume_type(backend)
    end
    not_if { backend['qos_enabled'] }
    only_if <<-DOC
      openstack volume qos show #{qos_name}
    DOC
  end # ruby block
end

if zone_config.alternate_backends_enabled?
  alternate_backends.each do |backend|
    backend_name = backend['backend_name']
    backend_properties = backend['volume_type_properties']
    create_args = [].append(backend_name)

    if backend['private']
      create_args.append('--private')
    else
      create_args.append('--public')
    end

    execute "create alternate backend type: #{backend_name}" do
      environment os_adminrc
      retries 3
      command <<-EOH
        openstack volume type create #{create_args.join(' ')}
      EOH
      not_if { node.run_state['os_vol_type_props'].key? backend_name }
    end

    execute "set cinder alternate backend properties for: #{backend_name}" do
      environment os_adminrc
      retries 3
      command <<-DOC
        openstack volume type set #{backend_name} \
          --property volume_backend_name=#{backend_name} \
          #{backend_properties}
      DOC

      not_if { node.run_state['os_vol_type_props'].dig(backend_name, 'volume_backend_name') == backend_name }
    end

    ruby_block "add a qos policy to the volume type #{backend_name}" do
      qos_name = "#{backend_name}-qos"
      block do
        add_qos_to_volume_type(backend)
      end
      only_if { backend['qos_enabled'] }
      not_if <<-DOC
        openstack volume qos show #{qos_name}
      DOC
    end # ruby block

    ruby_block "remove the qos policy from the volume type #{backend_name}" do
      qos_name = "#{backend_name}-qos"
      block do
        remove_qos_from_volume_type(backend)
      end
      not_if { backend['qos_enabled'] }
      only_if <<-DOC
        openstack volume qos show #{qos_name}
      DOC
    end # ruby block
  end # for loop
end # if
