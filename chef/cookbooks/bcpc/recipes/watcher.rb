# Cookbook:: bcpc
# Recipe:: watcher
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

return unless node['bcpc']['watcher']['enabled']

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
  'dbname' => node['bcpc']['watcher']['db']['dbname'],
  'username' => config['watcher']['creds']['db']['username'],
  'password' => config['watcher']['creds']['db']['password'],
}

# watcher openstack access
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['watcher']['creds']['os']['username'],
  'password' => config['watcher']['creds']['os']['password'],
}

# create watcher service user
execute 'create openstack watcher user' do
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

ruby_block 'collect openstack service and endpoints list' do
  block do
    node.run_state['os_endpoints'] = openstack_endpoints()
    node.run_state['os_services'] = openstack_services()
  end
  action :run
end

# create infra-optim service and endpoints
begin
  type = 'infra-optim'
  service = node['bcpc']['catalog'][type]
  name = service['name']

  execute "create the #{name} service" do
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

# watcher packages installation and service definitions
watcher_packages = %w(watcher-api watcher-decision-engine watcher-applier python3-watcherclient)
package watcher_packages

service 'watcher-decision-engine'

service 'watcher-applier'

service 'watcher-api' do
  action [:stop, :disable]
end

service 'haproxy-watcher' do
  service_name 'haproxy'
end

service 'watcher-apis-apache2' do
  service_name 'apache2'
end

watcher_processes = if !node['bcpc']['watcher']['api_workers'].nil?
                      node['bcpc']['watcher']['api_workers']
                    else
                      node['bcpc']['openstack']['services']['workers']
                    end

# configure watcher-api service
template '/etc/apache2/sites-available/watcher-api.conf' do
  source 'watcher/watcher-api.conf.erb'
  mode '0640'
  owner 'root'
  group 'watcher'

  variables(
    processes: watcher_processes
  )
  notifies :run, 'execute[enable watcher-api]', :immediately
  notifies :restart, 'service[watcher-apis-apache2]', :immediately
  notifies :create, "bcpc_proxysql_user[create #{database['username']} "\
    'proxysql user]', :immediately
  notifies :create, 'template[/tmp/watcher-create-db.sql]', :immediately
end

execute 'enable watcher-api' do
  command 'a2ensite watcher-api'
  not_if 'a2query -s watcher-api'
end

# create policy.d dir for policy overrides
directory '/etc/watcher/policy.d' do
  action :create
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

# create/manage watcher database starts
file '/tmp/watcher-create-db.sql' do
  action :nothing
end

template '/tmp/watcher-create-db.sql' do
  source 'watcher/watcher-create-db.sql.erb'
  variables(
    db: database
  )
  notifies :run, 'execute[create watcher database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create watcher database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])
  command "mysql -u #{mysqladmin['username']} < /tmp/watcher-create-db.sql"
  notifies :delete, 'file[/tmp/watcher-create-db.sql]', :immediately
end

template '/etc/watcher/watcher.conf' do
  source 'watcher/watcher.conf.erb'
  mode '0640'
  owner 'root'
  group 'watcher'

  variables(
    db: database,
    os: openstack,
    config: config,
    is_headnode: headnode?,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :run, 'execute[watcher-manage db_sync]', :immediately
  notifies :restart, 'service[watcher-decision-engine]', :immediately
  notifies :restart, 'service[watcher-apis-apache2]', :immediately
  notifies :restart, 'service[watcher-applier]', :immediately
end

execute 'watcher-manage db_sync' do
  action :nothing
  command "su -s /bin/sh -c 'watcher-db-manage --config-file /etc/watcher/watcher.conf upgrade'"
end

# install haproxy fragment
template '/etc/haproxy/haproxy.d/watcher.cfg' do
  source 'watcher/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :reload, 'service[haproxy-watcher]', :immediately
end

execute 'wait for watcher api to become available' do
  environment os_adminrc
  retries 15
  command 'openstack optimize strategy list'
end
