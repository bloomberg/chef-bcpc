# Cookbook Name:: bcpc
# Recipe:: designate
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

mysqladmin = mysqladmin()

# hash used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['designate']['db']['dbname'],
  'username' => config['designate']['creds']['db']['username'],
  'password' => config['designate']['creds']['db']['password'],
}

# hash used for openstack access
#
openstack = {
  'username' => config['designate']['creds']['os']['username'],
  'password' => config['designate']['creds']['os']['password'],
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
}

# create/configure designate openstack user starts
#
execute 'create the designate user' do
  environment os_adminrc

  command <<-DOC
    openstack user create \
      --domain default \
      --password #{openstack['password']} \
      #{openstack['username']}
  DOC

  not_if "openstack user show --domain default #{openstack['username']}"
end

execute 'add admin role to the designate user' do
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
# create/configure designate openstack user ends

# create dns service and endpoints starts
#
begin
  type = 'dns'
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
        openstack endpoint create --region #{region} #{type} #{uri} '#{url}'
      DOC

      not_if "openstack endpoint list | grep #{type} | grep #{uri}"
    end
  end
end
#
# create dns service and endpoints ends

# designate package installation and service definition starts
#
package 'designate'
package 'designate-worker'
package 'designate-producer'
package 'designate-mdns'
package 'bind9utils'

service 'designate-api'
service 'designate-agent'
service 'designate-central'
service 'designate-worker'
service 'designate-producer'
service 'designate-mdns'

# create/manage designate database starts
#
file '/tmp/designate-create-db.sql' do
  action :nothing
end

template '/tmp/designate-create-db.sql' do
  source 'designate/create-db.sql.erb'
  variables(
    'db' => database
  )
  notifies :run, 'execute[create designate database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create designate database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])
  command "mysql -u #{mysqladmin['username']} < /tmp/designate-create-db.sql"
  notifies :delete, 'file[/tmp/designate-create-db.sql]', :immediately
  notifies :create, 'template[/etc/designate/designate.conf]', :immediately
  notifies :run, 'execute[designate-manage database sync]', :immediately
end

execute 'designate-manage database sync' do
  action :nothing
  command <<-DOC
    su -s /bin/sh -c "designate-manage database sync" designate
  DOC
end

execute 'designate-manage pool update' do
  action :nothing
  command <<-DOC
    su -s /bin/sh -c "designate-manage pool update" designate
  DOC
end
#
# create/manage designate database ends

# configure components starts
#
template '/etc/designate/designate.conf' do
  source 'designate/designate.conf.erb'

  variables(
    db: database,
    os: openstack,
    config: config,
    headnodes: headnodes(all: true)
  )

  notifies :restart, 'service[designate-api]', :immediately
  notifies :restart, 'service[designate-agent]', :immediately
  notifies :restart, 'service[designate-central]', :immediately
  notifies :restart, 'service[designate-worker]', :immediately
  notifies :restart, 'service[designate-producer]', :immediately
  notifies :restart, 'service[designate-mdns]', :immediately
end

template '/etc/designate/pools.yaml' do
  source 'designate/pools.yaml.erb'

  variables(
    headnodes: headnodes(all: true),
    api_key: config['powerdns']['creds']['api']['key']
  )

  notifies :run, 'execute[designate-manage pool update]', :immediately
end
#
# configure components ends

execute 'wait for designate to come online' do
  environment os_adminrc
  retries 15
  command 'openstack dns service list'
end
