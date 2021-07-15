# Cookbook:: bcpc
# Recipe:: keystone
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
  'dbname' => node['bcpc']['keystone']['db']['dbname'],
  'username' => config['keystone']['db']['username'],
  'password' => config['keystone']['db']['password'],
}

# install haproxy fragment
template '/etc/haproxy/haproxy.d/keystone.cfg' do
  source 'keystone/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-keystone]', :immediately
end

# package installation and service definition starts
package %w(
  keystone
  python3-ldap
  python3-ldappool
)

service 'keystone' do
  service_name 'apache2'
end

service 'haproxy-keystone' do
  service_name 'haproxy'
end

# fernet key installation starts
directory '/etc/keystone/fernet-keys' do
  mode '700'
  owner 'keystone'
  group 'keystone'
end

file '/etc/keystone/fernet-keys/2' do
  mode '600'
  owner 'keystone'
  group 'keystone'
  content config['keystone']['fernet']['keys']['primary']
end

file '/etc/keystone/fernet-keys/1' do
  mode '600'
  owner 'keystone'
  group 'keystone'
  content config['keystone']['fernet']['keys']['secondary']
end

file '/etc/keystone/fernet-keys/0' do
  mode '600'
  owner 'keystone'
  group 'keystone'
  content config['keystone']['fernet']['keys']['staged']
end
# fernet key installation ends

# additional domain configuration directory
domain_config_dir = node['bcpc']['keystone']['domain_config_dir']

directory domain_config_dir do
  mode '700'
  owner 'keystone'
  group 'keystone'
end

execute 'disable old keystone config' do
  command 'a2dissite keystone'
  only_if 'a2query -s keystone'
end

file '/etc/apache2/sites-available/keystone.conf' do
  action :delete
end

# configure apache2 wsgi proxy vhost
keystone_processes = if !node['bcpc']['keystone']['workers'].nil?
                       node['bcpc']['keystone']['workers']
                     else
                       node['bcpc']['openstack']['services']['workers']
                     end

template '/etc/apache2/sites-available/keystone-api.conf' do
  source 'keystone/keystone-api.conf.erb'
  mode '644'
  variables(
    processes: keystone_processes
  )
  notifies :run, 'execute[enable keystone-api]', :immediately
  notifies :reload, 'service[keystone]', :immediately
end

execute 'enable keystone-api' do
  command 'a2ensite keystone-api'
  not_if 'a2query -s keystone-api'
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

# create/bootstrap keystone
file '/tmp/keystone-create-db.sql' do
  action :nothing
end

template '/tmp/keystone-create-db.sql' do
  source 'keystone/keystone-create-db.sql.erb'

  variables(
    database: database
  )

  notifies :run, 'execute[create keystone database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create keystone database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

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
  admin_url = generate_service_catalog_uri(service, 'admin')
  internal_url = generate_service_catalog_uri(service, 'internal')
  public_url = generate_service_catalog_uri(service, 'public')

  command <<-DOC
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
  DOC
end

# create policy.d dir for policy overrides
directory '/etc/keystone/policy.d' do
  action :create
end

# install override for cloud_admin definition
cookbook_file '/etc/keystone/policy.d/cloud_admin.json' do
  source 'keystone/cloud_admin.json'
end

# configure keystone service starts
template '/etc/keystone/keystone.conf' do
  source 'keystone/keystone.conf.erb'
  mode '0640'
  owner 'root'
  group 'keystone'

  variables(
    db: database,
    headnodes: headnodes(all: true)
  )

  notifies :restart, 'service[keystone]', :immediately
end

# generate admin-openrc for openstack cli usage
template '/root/admin-openrc' do
  source 'keystone/admin-openrc.erb'
  variables(
    'os_adminrc' => os_adminrc
  )
end

# create openstack config directory
directory '/etc/openstack' do
  action :create
  recursive true
end

template '/etc/openstack/clouds.yml' do
  source 'openstack/clouds.yml.erb'
  owner 'root'
  group 'operators'
  mode '0640'
  variables(
    'os_adminrc' => os_adminrc
  )
end

# add OS_CLOUD environment variable to /etc/environment
# so that --os-cloud does not need to be given to the openstack cli
# when accessing the local cloud
bash 'add OS_CLOUD var to /etc/environment' do
  code <<-EOH
    env_variable="OS_CLOUD=#{os_adminrc['OS_REGION_NAME']}"
    grep -qxF "${env_variable}" /etc/environment \
      || echo "${env_variable}" >> /etc/environment
  EOH
end

execute 'wait for keystone to come online' do
  environment os_adminrc
  retries 15
  command 'openstack catalog list'
end

execute 'update admin project description' do
  environment os_adminrc

  desc = 'Admin Project'
  project = node['bcpc']['openstack']['admin']['project']

  command <<-DOC
    openstack project set \
      --description "#{desc}" \
      --domain default #{project}
  DOC

  not_if <<-DOC
    openstack project show \
      -f value -c description #{project} | grep "#{desc}"
  DOC
end

execute 'add admin role to admin user in default domain' do
  environment os_adminrc
  command <<-EOH
    openstack role add admin --domain default --user admin
  EOH

  not_if <<-DOC
    openstack role assignment list \
      --names \
      --user admin \
      --role admin \
      --domain default | grep admin
  DOC
end

execute 'set default project for admin user in default domain' do
  environment os_adminrc
  command <<-EOH
    openstack user set --domain default --project admin admin
  EOH

  not_if <<-DOC
    default_project_id=$(openstack project show -c id -f value admin)
    openstack user show -c default_project_id --domain default admin | \
      grep ${default_project_id}
  DOC
end

execute 'create the service project' do
  environment os_adminrc

  service_project = node['bcpc']['keystone']['service_project']
  project_name    = service_project['name']
  project_domain  = service_project['domain']

  command <<-DOC
    openstack project create \
      --domain #{project_domain} \
      --description "Service Project" #{project_name}
  DOC

  not_if "openstack project show --domain #{project_domain} #{project_name}"
end

# setup additional domains
node['bcpc']['keystone']['domains'].each do |domain|
  domain_name = domain['name']

  template File.join(domain_config_dir, "keystone.#{domain_name}.conf") do
    source 'keystone/keystone.domain.conf.erb'
    mode '600'
    owner 'keystone'
    group 'keystone'

    variables(
      identity: domain['identity']
    )
  end

  execute 'create openstack domain' do
    environment os_adminrc

    description = domain['description'] || ''

    command <<-DOC
      openstack domain create --description "#{description}" #{domain_name}
    DOC

    not_if "openstack domain show #{domain_name}"
  end

  # run mapping_populate to improve future ldap queries
  execute 'keystone-manage mapping_populate' do
    environment os_adminrc
    command <<-DOC
      keystone-manage mapping_populate --domain #{domain_name}
    DOC
  end

  execute "add admin role to admin user in the #{domain_name} domain" do
    environment os_adminrc

    command <<-EOH
      openstack role add admin --domain #{domain_name} --user admin
    EOH

    not_if <<-DOC
      openstack role assignment list \
        --names \
        --user admin \
        --role admin \
        --domain #{domain_name} | grep admin
    DOC
  end
end
