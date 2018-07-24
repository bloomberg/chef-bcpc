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

mysql_root_user     = get_config('mysql-root-user')
mysql_root_password = get_config('mysql-root-password')

keystone_db = node['bcpc']['dbname']['keystone']
keystone_db_user = make_config('mysql-keystone-user', "keystone")
keystone_db_password = make_config('mysql-keystone-password', secure_password)
make_config('keystone-local-admin-password', secure_password)
make_config('keystone-local-admin-user',
            node['bcpc']['keystone']['admin']['username'])


# package installation and service definition starts
#
%w(keystone python-ldappool).each do |pkg|
  package pkg do
    action :upgrade
  end
end

package 'python-ldappool' do
  action :install
end
#
# package installation and service definition starts

package 'keystone' do
  action :install
  notifies :run, 'bash[flush-memcached]', :immediately
end

# fernet key initialization and possible rotation starts
#
primary = make_config('fernet_primary_key', generate_fernet_key())
secondary = make_config('fernet_secondary_key', generate_fernet_key())
staged = make_config('fernet_staged_key', generate_fernet_key())
make_config('fernet_last_rotation', Time.now.to_i)

# these packages need to be updated in Liberty but are not upgraded when Keystone is upgraded
%w( python-oslo.i18n python-oslo.serialization python-pyasn1 ).each do |pkg|
  package pkg do
    action :install
    notifies :restart, "service[apache2]", :immediately
  end
end

  # update data bag values with rotation
  #
  make_config('fernet_primary_key',staged,force=true)
  make_config('fernet_secondary_key',primary,force=true)
  make_config('fernet_staged_key',generate_fernet_key(),force=true)

  # update last rotation timestamp
  #
  make_config('fernet_last_rotation', Time.now.to_i, force=true)
end

directory '/etc/keystone/fernet-keys' do
  owner 'keystone'
  group 'keystone'
  mode "0700"
end

file '/etc/keystone/fernet-keys/2' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{get_config('fernet_primary_key')}"
end

file '/etc/keystone/fernet-keys/1' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{get_config('fernet_secondary_key')}"
end

file '/etc/keystone/fernet-keys/0' do
  owner 'keystone'
  group 'keystone'
  mode "0600"
  content "#{get_config('fernet_staged_key')}"
end
#
# fernet key initialization and possible rotation ends


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
    'keystone_db' => keystone_db,
    'keystone_db_user' => keystone_db_user,
    'keystone_db_password' => keystone_db_password
  )

  notifies :run, 'execute[create keystone database]', :immediately
  not_if "mysql -u #{mysql_root_user} \
                -e 'show databases' | grep #{keystone_db}",
         :environment => {'MYSQL_PWD' => mysql_root_password}
end

execute 'create keystone database' do
  action :nothing
  environment ({'MYSQL_PWD' => mysql_root_password})

  command "mysql -u #{mysql_root_user} < /tmp/keystone-create-db.sql"

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

  region_name           = node['bcpc']['region_name']
  admin_username        = get_config('keystone-local-admin-user')
  admin_password        = get_config('keystone-local-admin-password')
  admin_role_name       = node['bcpc']['keystone']['admin_role']
  admin_project_name    = node['bcpc']['keystone']['admin']['project_name']

  type = 'identity'
  service = node['bcpc']['catalog'][type]
  name = service['name']
  admin_url = generate_service_catalog_uri(service,'admin')
  internal_url = generate_service_catalog_uri(service,'internal')
  public_url = generate_service_catalog_uri(service,'public')

  command <<-EOH
    keystone-manage bootstrap \
      --bootstrap-service-name #{name} \
      --bootstrap-region-id #{region_name} \
      --bootstrap-username #{admin_username} \
      --bootstrap-password #{admin_password} \
      --bootstrap-role-name #{admin_role_name} \
      --bootstrap-project-name #{admin_project_name} \
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
    'servers' => get_head_nodes()
  )

  notifies :restart, 'service[keystone]', :immediately
end

template "/etc/keystone/policy.json" do
  source "keystone-policy.json.erb"
  owner "keystone"
  group "keystone"
  mode "0600"

  policy = node['bcpc']['keystone']['policy']

  variables(
    :policy => JSON.pretty_generate(policy)
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
  admin_project_name = node['bcpc']['keystone']['admin']['project_name']

  command <<-EOH
    openstack project set \
      --description "#{desc}" \
      --domain default \
      #{admin_project_name}
  EOH

  not_if <<-EOH
    openstack project show \
      -f value -c description #{admin_project_name} | grep "#{desc}"
  EOH
end

execute "create the default member role" do
  environment (os_adminrc())

  role = node['bcpc']['keystone']['member_role']

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
      --description "Service Project" \
      #{project_name}
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


# generate admin-openrc for openstack cli usage
#
template '/root/admin-openrc' do
  source 'admin-openrc.erb'
  variables(
    'os_adminrc' => os_adminrc()
  )
end

# Cleanup actions
file '/var/lib/keystone/keystone.db' do
  action :delete
end

link '/root/keystonerc' do
  to '/root/openrc-admin-token'
end

link '/root/adminrc' do
  to adminrc
end

template "/etc/logrotate.d/keystone" do
    source "keystone/keystone.logrotate.conf.erb"
    owner "root"
    group "root"
    mode 00644
end
