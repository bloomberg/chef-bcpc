#
# Cookbook Name:: bcpc
# Recipe:: keystone
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

config = data_bag_item(node['bcpc']['cloud']['region'],'config')

database = {
  'dbname' => node['bcpc']['keystone']['db'],
  'username' => config['keystone']['db']['username'],
  'password' => config['keystone']['db']['password']
}

mysqladmin = mysqladmin()

# package installation and service definition starts
#
%w(keystone python-ldap python-ldappool).each do |pkg|
  package pkg
end

service 'keystone' do
  service_name 'apache2'
end
#
# package installation and service definition starts


# fernet key installation starts
#
directory '/etc/keystone/fernet-keys' do
  owner 'keystone'
  group 'keystone'
  mode "0700"
end

file '/etc/keystone/fernet-keys/2' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{config['keystone']['fernet']['keys']['primary']}"
end

file '/etc/keystone/fernet-keys/1' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{config['keystone']['fernet']['keys']['secondary']}"
end

file '/etc/keystone/fernet-keys/0' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{config['keystone']['fernet']['keys']['staged']}"
end
#
# fernet key installation ends


# additional domain configuration directory
#
domain_config_dir = node['bcpc']['keystone']['domain_config_dir']

directory domain_config_dir do
  owner "keystone"
  group "keystone"
  mode "2700"
end


# configure apache2 wsgi proxy vhost starts
#
template "/etc/apache2/sites-available/keystone.conf" do
  source "keystone/apache-keystone.conf.erb"
  mode "0644"

  variables(
    'processes' => node['bcpc']['keystone']['wsgi']['processes'],
    'threads'   => node['bcpc']['keystone']['wsgi']['threads']
  )

  notifies :reload, "service[keystone]", :immediately
end
#
# configure apache2 wsgi proxy vhost ends


# create/bootstrap keystone starts
#
file '/tmp/keystone-create-db.sql' do
  action :nothing
end

template '/tmp/keystone-create-db.sql' do
  source 'keystone/keystone-create-db.sql.erb'

  variables(
    :database => database
  )

  notifies :run, 'execute[create keystone database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", :environment => {'MYSQL_PWD' => mysqladmin['password']}
end

execute 'create keystone database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysqladmin['password']})

  command "mysql -u #{mysqladmin['username']} < /tmp/keystone-create-db.sql"

  notifies :delete, 'file[/tmp/keystone-create-db.sql]', :immediately
  notifies :create, 'template[/etc/keystone/keystone.conf]', :immediately
  notifies :run, 'execute[keystone-manage db_sync]', :immediately
  notifies :run, 'execute[bootstrap the identity service]', :immediately
end

execute 'keystone-manage db_sync' do
  action :nothing
  command "su -s /bin/sh -c 'keystone-manage db_sync' keystone"
end

execute 'bootstrap the identity service' do
  action :nothing

  region = node['bcpc']['cloud']['region']
  username = node['bcpc']['openstack']['admin']['username']
  password = config['openstack']['admin']['password']
  role = node['bcpc']['keystone']['roles']['admin']
  project = node['bcpc']['openstack']['admin']['project']

  type = 'identity'
  service = node['bcpc']['catalog'][type]
  name = service['name']
  admin_url = generate_service_catalog_uri(service,'admin')
  internal_url = generate_service_catalog_uri(service,'internal')
  public_url = generate_service_catalog_uri(service,'public')

  command <<-EOH
    keystone-manage bootstrap \
      --bootstrap-service-name #{name} \
      --bootstrap-region-id #{region} \
      --bootstrap-username #{username} \
      --bootstrap-password #{password} \
      --bootstrap-role-name #{role} \
      --bootstrap-project-name #{project} \
      --bootstrap-admin-url #{admin_url} \
      --bootstrap-internal-url #{internal_url} \
      --bootstrap-public-url #{public_url}
  EOH
end
#
# create/bootstrap keystone ends


# configure keystone service starts
#
template '/etc/keystone/keystone.conf' do
  source 'keystone/keystone.conf.erb'

  variables(
    :db => database,
    :headnodes => get_headnodes(all:true)
  )

  notifies :restart, 'service[keystone]', :immediately
end


# generate admin-openrc for openstack cli usage
#
template '/root/admin-openrc' do
  source 'admin-openrc.erb'
  variables(
    'os_adminrc' => os_adminrc()
  )
end

execute 'wait for keystone to come online' do
  environment (os_adminrc())
  retries 15
  command "openstack catalog list"
end

execute 'update admin project description' do
  environment (os_adminrc())

  desc = 'Admin Project'
  project = node['bcpc']['openstack']['admin']['project']

  command <<-EOH
    openstack project set \
      --description "#{desc}" \
      --domain default #{project}
  EOH

  not_if <<-EOH
    openstack project show \
      -f value -c description #{project} | grep "#{desc}"
  EOH
end

execute "create the default member role" do
  environment (os_adminrc())

  role = node['bcpc']['keystone']['roles']['member']

  command <<-EOH
    openstack role create #{role}
  EOH

  not_if "openstack role show #{role}"
end

execute 'create the service project' do
  environment (os_adminrc())

  service_project = node['bcpc']['keystone']['service_project']
  project_name    = service_project['name']
  project_domain  = service_project['domain']

  command <<-EOH
    openstack project create \
      --domain #{project_domain} \
      --description "Service Project" #{project_name}
  EOH

  not_if "openstack project show --domain #{project_domain} #{project_name}"
end
#
# configure keystone service ends


# setup additional domains starts
#
node['bcpc']['keystone']['domains'].each do |domain, config|

  config_file = File.join domain_config_dir, "keystone.#{domain}.conf"

  template config_file do
    source "keystone/keystone.domain.conf.erb"

    owner "keystone"
    group "keystone"
    mode "0600"

    variables(
      :domain => config
    )

    notifies :run, "execute[create openstack domain]", :immediately
    not_if "openstack domain show #{domain}", :environment => os_adminrc()
  end

  execute "create openstack domain" do
    action :nothing
    environment (os_adminrc())

    desc = domain['description'] || ''

    command <<-EOH
      openstack domain create --description "#{desc}" #{domain}
    EOH

    notifies :run, "execute[upload domain configuration]", :immediately
  end

  execute "upload domain configuration" do
    action :nothing
    environment (os_adminrc())

    command <<-EOH
       keystone-manage domain_config_upload --domain "#{domain}"
    EOH
  end

end
#
# setup additional domains ends
