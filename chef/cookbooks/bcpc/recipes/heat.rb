# Cookbook:: bcpc
# Recipe:: heat
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

return unless node['bcpc']['heat']['enabled']

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

mysqladmin = mysqladmin()

database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['heat']['db']['dbname'],
  'username' => config['heat']['creds']['db']['username'],
  'password' => config['heat']['creds']['db']['password'],
}

# heat openstack access
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['heat']['creds']['os']['username'],
  'password' => config['heat']['creds']['os']['password'],
}

# create heat service user
execute 'create openstack heat user' do
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

# create heat domain
execute 'create heat domain' do
  environment os_adminrc
  command <<-DOC
    openstack domain create --description 'Stack projects and users' heat
  DOC
  not_if 'openstack domain show heat'
end

# create heat_domain_admin user
execute 'create heat_domain_admin user' do
  environment os_adminrc
  command <<-DOC
    openstack user create heat_domain_admin \
      --domain heat \
      --password #{openstack['password']}
  DOC
  not_if 'openstack user show heat_domain_admin --domain heat'
end

# add admin role to heat_domain_admin user in heat domain
execute 'add admin role to heat_domain_admin user in heat domain' do
  environment os_adminrc
  command <<-DOC
   openstack role add --domain heat --user-domain heat \
     --user heat_domain_admin admin
  DOC

  not_if <<-DOC
    openstack role assignment list \
      --names \
      --role admin \
      --domain heat \
      --user-domain heat \
      --user heat_domain_admin | grep heat_domain_admin
  DOC
end

# create heat_stack_owner role
execute 'create heat_stack_owner role' do
  environment os_adminrc
  command 'openstack role create heat_stack_owner'
  not_if 'openstack role show heat_stack_owner'
end

# create heat_stack_user role
execute 'create heat_stack_user role' do
  environment os_adminrc
  command 'openstack role create heat_stack_user'
  not_if 'openstack role show heat_stack_user'
end

# add heat_stack_owner role to admin user in admin project
execute 'add heat_stack_owner role to admin user in admin project' do
  environment os_adminrc
  command 'openstack role add --project admin --user admin heat_stack_owner'
  not_if <<-DOC
    openstack role assignment list \
      --names \
      --role heat_stack_owner \
      --project admin \
      --user admin | grep admin
  DOC
end

# create orchestration service and endpoints
begin
  type = 'orchestration'
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

# create cloudformation service and endpoints
begin
  type = 'cloudformation'
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

# install haproxy fragment
template '/etc/haproxy/haproxy.d/heat.cfg' do
  source 'heat/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :restart, 'service[haproxy-heat]', :immediately
end

# heat packages installation and service definitions
heat_packages = %w(heat-api heat-api-cfn heat-engine)
package heat_packages

service 'heat-engine'

service 'heat-api' do
  action [:stop, :disable]
end

service 'heat-api-cfn' do
  action [:stop, :disable]
end

service 'heat-apis-apache2' do
  service_name 'apache2'
end

service 'haproxy-heat' do
  service_name 'haproxy'
end

execute 'wait for heat api to become available' do
  environment os_adminrc
  retries 15
  command 'openstack stack list'
  action :nothing
  subscribes :run, 'service[heat-apis-apache2]', :immediately
end

heat_processes = if !node['bcpc']['heat']['api_workers'].nil?
                   node['bcpc']['heat']['api_workers']
                 else
                   node['bcpc']['openstack']['services']['workers']
                 end

# configure heat-api service
template '/etc/apache2/sites-available/heat-api.conf' do
  source 'heat/heat-api.conf.erb'
  variables(
    processes: heat_processes
  )
  notifies :run, 'execute[enable heat-api]', :immediately
  notifies :create, 'template[/etc/apache2/sites-available/heat-api-cfn.conf]',
           :immediately
  notifies :create, 'template[/tmp/heat-create-db.sql]', :immediately
end

execute 'enable heat-api' do
  command 'a2ensite heat-api'
  not_if 'a2query -s heat-api'
end

# configure heat-api-cfn service
template '/etc/apache2/sites-available/heat-api-cfn.conf' do
  source 'heat/heat-api-cfn.conf.erb'
  variables(
    processes: heat_processes
  )
  notifies :run, 'execute[enable heat-api-cfn]', :immediately
  notifies :create, 'template[/tmp/heat-create-db.sql]', :immediately
end

execute 'enable heat-api-cfn' do
  command 'a2ensite heat-api-cfn'
  not_if 'a2query -s heat-api-cfn'
end

# create policy.d dir for policy overrides
directory '/etc/heat/policy.d' do
  action :create
end

# create/manage heat database starts
file '/tmp/heat-create-db.sql' do
  action :nothing
end

template '/tmp/heat-create-db.sql' do
  source 'heat/heat-create-db.sql.erb'
  variables(
    db: database
  )
  notifies :run, 'execute[create heat database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create heat database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])
  command "mysql -u #{mysqladmin['username']} < /tmp/heat-create-db.sql"
  notifies :delete, 'file[/tmp/heat-create-db.sql]', :immediately
  notifies :create, 'template[/etc/heat/heat.conf]', :immediately
  notifies :run, 'execute[heat-manage db_sync]', :immediately
  notifies :restart, 'service[heat-engine]', :immediately
end

execute 'heat-manage db_sync' do
  action :nothing
  command "su -s /bin/sh -c 'heat-manage db_sync' heat"
end

# configure heat
template '/etc/heat/heat.conf' do
  source 'heat/heat.conf.erb'
  variables(
    db: database,
    os: openstack,
    config: config,
    is_headnode: headnode?,
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :run, 'execute[heat-manage db_sync]', :immediately
  notifies :restart, 'service[heat-engine]', :immediately
  notifies :restart, 'service[heat-apis-apache2]', :immediately
end
