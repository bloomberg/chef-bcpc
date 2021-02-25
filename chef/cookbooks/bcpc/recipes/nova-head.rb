# Cookbook:: bcpc
# Recipe:: nova-head
#
# Copyright:: 2020 Bloomberg Finance L.P.
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
nova_config = zone_config.nova_config

mysqladmin = mysqladmin()

# used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['nova']['db']['dbname'],
  'username' => config['nova']['creds']['db']['username'],
  'password' => config['nova']['creds']['db']['password'],
}

# nova openstack access
#
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['nova']['creds']['os']['username'],
  'password' => config['nova']['creds']['os']['password'],
}

# create nova user starts
#
execute 'create openstack nova user' do
  environment os_adminrc

  command <<-DOC
    openstack user create #{openstack['username']} \
      --domain #{openstack['domain']} \
      --password #{openstack['password']}
  DOC

  not_if "
    openstack user show #{openstack['username']} \
      --domain #{openstack['domain']}
  "
end

execute "add #{openstack['role']} role to #{openstack['username']} user" do
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
# create nova user ends

# create compute service and endpoints starts
#
begin
  type = 'compute'
  service = node['bcpc']['catalog'][type]
  name = service['name']

  execute "create the #{name} service" do
    environment os_adminrc

    desc = service['description']

    command <<-DOC
      openstack service create --name "#{name}" --description "#{desc}" #{type}
    DOC

    not_if "openstack service list | grep #{type}"
  end

  %w(admin internal public).each do |uri|
    url = generate_service_catalog_uri(service, uri)

    execute "create the #{name} #{type} #{uri} endpoint" do
      environment os_adminrc

      command <<-DOC
        openstack endpoint create --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if "openstack endpoint list | grep #{type} | grep #{uri}"
    end
  end
end
#
# create compute service and endpoints ends

# nova openstack access
#
placement = {
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
    openstack user create #{placement['username']} \
      --domain #{placement['domain']} \
      --password #{placement['password']}
  DOC

  not_if "openstack user show #{placement['username']} --domain default"
end

execute 'add admin role to placement user' do
  environment os_adminrc

  command <<-DOC
    openstack role add #{placement['role']} \
      --project #{placement['project']} \
      --user #{placement['username']}
  DOC

  not_if <<-DOC
    openstack role assignment list \
      --names \
      --role #{placement['role']} \
      --project #{placement['project']} \
      --user #{placement['username']} | grep #{placement['username']}
  DOC
end
#
# create placement user ends

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

    not_if "openstack service list | grep #{type}"
  end

  %w(admin internal public).each do |uri|
    url = generate_service_catalog_uri(service, uri)

    execute "create the #{name} #{type} #{uri} endpoint" do
      environment os_adminrc

      command <<-DOC
        openstack endpoint create \
          --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if "openstack endpoint list | grep #{type} | grep #{uri}"
    end
  end
end
#
# create placement service and endpoints ends

# install haproxy fragment
template '/etc/haproxy/haproxy.d/nova.cfg' do
  source 'nova/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-nova]', :immediately
end

# nova package installation and service definition
package %w(
  nova-api
  nova-conductor
  nova-consoleauth
  nova-novncproxy
  nova-scheduler
  nova-placement-api
)

service 'nova-api'
service 'nova-consoleauth'
service 'nova-scheduler'
service 'nova-conductor'
service 'nova-novncproxy'
service 'placement-api' do
  service_name 'apache2'
end
service 'haproxy-nova' do
  service_name 'haproxy'
end

# create policy.d dir for policy overrides
directory '/etc/nova/policy.d' do
  action :create
end

file '/etc/nova/ssl-bcpc.pem' do
  content Base64.decode64(config['ssl']['key']).to_s
  mode '644'
  owner 'nova'
  group 'nova'
end

file '/etc/nova/ssl-bcpc.key' do
  content Base64.decode64(config['ssl']['key']).to_s
  mode '600'
  owner 'nova'
  group 'nova'
end
#
# ssl certs ends

# create ceph rbd pools
nova_config.ceph_pools.each do |pool|
  pool_name = pool['pool']
  pg_num = node['bcpc']['ceph']['pg_num']
  pgp_num = node['bcpc']['ceph']['pgp_num']

  bash "create the #{pool_name} ceph pool" do
    code <<-DOC
      ceph osd pool create #{pool_name} #{pg_num} #{pgp_num}
      ceph osd pool application enable #{pool_name} rbd
    DOC

    not_if "ceph osd pool ls | grep -w ^#{pool_name}$"
  end

  execute 'set ceph pool size' do
    size = node['bcpc']['nova']['ceph']['pool']['size']
    command "ceph osd pool set #{pool_name} size #{size}"
    not_if "ceph osd pool get #{pool_name} size | grep -w 'size: #{size}'"
  end
end
# create ceph rbd pools ends

# create/manage nova databases starts
#
file '/tmp/nova-create-db.sql' do
  action :nothing
end

template '/tmp/nova-create-db.sql' do
  source 'nova/nova-create-db.sql.erb'

  variables(
    db: database
  )

  notifies :run, 'execute[create nova databases]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create nova databases' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

  command "mysql -u #{mysqladmin['username']} < /tmp/nova-create-db.sql"

  notifies :delete, 'file[/tmp/nova-create-db.sql]', :immediately
  notifies :create, 'template[/etc/nova/nova.conf]', :immediately
  notifies :run, 'execute[nova-manage api_db sync]', :immediately
  notifies :run, 'execute[register the cell0 database]', :immediately
  notifies :run, 'execute[create the cell1 cell]', :immediately
  notifies :run, 'execute[nova-manage db sync]', :immediately
  notifies :run, 'execute[update cell1]', :immediately
  notifies :restart, 'service[nova-api]', :immediately
  notifies :restart, 'service[nova-consoleauth]', :immediately
  notifies :restart, 'service[nova-scheduler]', :immediately
  notifies :restart, 'service[nova-conductor]', :immediately
  notifies :restart, 'service[nova-novncproxy]', :immediately
end

execute 'nova-manage api_db sync' do
  action :nothing
  command "su -s /bin/sh -c 'nova-manage api_db sync' nova"
end

execute 'register the cell0 database' do
  action :nothing
  command 'su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova'
  not_if 'nova-manage cell_v2 list_cells | grep cell0'
end

execute 'create the cell1 cell' do
  action :nothing
  command 'su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1" nova'
  not_if 'nova-manage cell_v2 list_cells | grep cell1'
end

execute 'nova-manage db sync' do
  action :nothing
  command 'su -s /bin/sh -c "nova-manage db sync" nova'
end
#
# create/manage nova databases ends

# add availibity zone anti affinity scheduler filter
available_filters = ['nova.scheduler.filters.all_filters']
enabled_filters = node['bcpc']['nova']['scheduler_default_filters']
anti_affinity = node['bcpc']['nova']['scheduler']['filter']['anti_affinity_availability_zone']

if anti_affinity['enabled']
  available_filters.push(anti_affinity['filterPath'])
  enabled_filters.push(anti_affinity['name'])

  cookbook_file '/usr/lib/python2.7/dist-packages/nova/scheduler/filters/anti_affinity_availability_zone_filter.py' do
    source 'nova/anti_affinity_availability_zone_filter.py'
    mode '0644'
    notifies :run, 'execute[compile az anti-affinity filter]', :immediately
    notifies :restart, 'service[nova-scheduler]', :immediately
  end

  execute 'compile az anti-affinity filter' do
    action :nothing
    command 'python -m compileall /usr/lib/python2.7/dist-packages/nova/scheduler/filters/anti_affinity_availability_zone_filter.py'
  end
end

# configure nova starts
template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'

  variables(
    available_filters: available_filters,
    enables_filters: enabled_fitler,
    db: database,
    os: openstack,
    config: config,
    is_headnode: headnode?,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )

  notifies :run, 'execute[update cell1]', :immediately
  notifies :restart, 'service[nova-api]', :immediately
  notifies :restart, 'service[nova-consoleauth]', :immediately
  notifies :restart, 'service[nova-scheduler]', :immediately
  notifies :restart, 'service[nova-conductor]', :immediately
  notifies :restart, 'service[nova-novncproxy]', :immediately
end

execute 'update cell1' do
  action :nothing
  command <<-DOC
    nova-manage cell_v2 update_cell --cell_uuid \
      $(nova-manage cell_v2 list_cells | grep cell1 | awk '{print $4}')
  DOC

  only_if 'nova-manage cell_v2 list_cells | grep cell1'
end
#
# configure nova ends

# configure placement-api starts
placement_processes = if !node['bcpc']['placement']['workers'].nil?
                        node['bcpc']['placement']['workers']
                      else
                        node['bcpc']['openstack']['services']['workers']
                      end

template '/etc/apache2/sites-available/nova-placement-api.conf' do
  source 'nova/nova-placement-api.conf.erb'
  variables(
    processes: placement_processes
  )
  notifies :run, 'execute[enable placement-api]', :immediately
  notifies :restart, 'service[placement-api]', :immediately
end
# configure placement-api ends

execute 'enable placement-api' do
  command 'a2ensite nova-placement-api'
  not_if 'a2query -s nova-placement-api'
end

cookbook_file '/etc/nova/api-paste.ini' do
  source 'nova/api-paste.ini'
  mode '0640'
  notifies :restart, 'service[nova-api]', :immediately
  notifies :restart, 'service[placement-api]', :immediately
end

execute 'wait for nova to come online' do
  environment os_adminrc
  retries 30
  command 'openstack compute service list'
end

cron 'nova-manage db archive' do
  action  :create
  minute  node['bcpc']['nova']['db-archive']['cron_minute']
  hour    node['bcpc']['nova']['db-archive']['cron_hour']
  weekday node['bcpc']['nova']['db-archive']['cron_weekday']
  day     node['bcpc']['nova']['db-archive']['cron_day']
  month   node['bcpc']['nova']['db-archive']['cron_month']
  user    'root'
  command <<-DOC
    /usr/local/bcpc/bin/if_leader \
    nova-manage db archive_deleted_rows --until-complete --verbose 2>&1 \
    | logger -t nova-db-archive-deleted-rows
  DOC
  only_if { node['bcpc']['nova']['db-archive']['enabled'] }
end
