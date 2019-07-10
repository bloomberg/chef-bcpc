# Cookbook:: bcpc
# Recipe:: cinder
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

mysqladmin = mysqladmin()

# hash used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
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
end
# create cinder volume services and endpoints ends

# install haproxy fragment
template '/etc/haproxy/haproxy.d/cinder.cfg' do
  source 'cinder/haproxy.cfg.erb'
  variables(
    headnodes: headnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :restart, 'service[haproxy-cinder]', :immediately
end

# cinder package installation and service definition
package 'cinder-api'
package 'cinder-scheduler'
package 'cinder-volume'

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

# create ceph rbd pool
bash 'create ceph pool' do
  pool = node['bcpc']['cinder']['ceph']['pool']['name']
  pg_num = node['bcpc']['ceph']['pg_num']
  pgp_num = node['bcpc']['ceph']['pgp_num']

  code <<-DOC
    ceph osd pool create #{pool} #{pg_num} #{pgp_num}
    ceph osd pool application enable #{pool} rbd
  DOC

  not_if "ceph osd pool ls | grep -w #{pool}"
end

execute 'set ceph pool size' do
  size = node['bcpc']['cinder']['ceph']['pool']['size']
  pool = node['bcpc']['cinder']['ceph']['pool']['name']

  command "ceph osd pool set #{pool} size #{size}"
  not_if "ceph osd pool get #{pool} size | grep -w 'size: #{size}'"
end

# create client.cinder ceph user and keyring
template '/etc/ceph/ceph.client.cinder.keyring' do
  source 'cinder/ceph.client.cinder.keyring.erb'

  mode '0640'
  owner 'root'
  group 'cinder'

  variables(
    key: config['ceph']['client']['cinder']['key']
  )
  notifies :run, 'execute[import cinder ceph client key]', :immediately
end

execute 'import cinder ceph client key' do
  action :nothing
  command 'ceph auth import -i /etc/ceph/ceph.client.cinder.keyring'
end

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
  notifies :create,
           'template[/etc/apache2/conf-available/cinder-wsgi.conf]',
           :immediately
  notifies :create, 'template[/etc/cinder/cinder.conf]', :immediately
  notifies :run, 'execute[cinder-manage db sync]', :immediately
end

execute 'cinder-manage db sync' do
  action :nothing
  command "su -s /bin/sh -c 'cinder-manage db sync' cinder"
end
# create/manage cinder database ends

# configure cinder service starts
template '/etc/apache2/conf-available/cinder-wsgi.conf' do
  source 'cinder/cinder-wsgi.conf.erb'
  variables(
    processes: node['bcpc']['cinder']['wsgi']['processes'],
    threads: node['bcpc']['cinder']['wsgi']['threads']
  )
  notifies :run, 'execute[enable cinder wsgi]', :immediately
  notifies :restart, 'service[cinder-api]', :immediately
end

execute 'enable cinder wsgi' do
  command 'a2enconf cinder-wsgi'
  not_if 'a2query -c cinder-wsgi'
end

template '/etc/cinder/cinder.conf' do
  source 'cinder/cinder.conf.erb'
  mode '600'
  owner 'cinder'
  group 'cinder'

  variables(
    db: database,
    config: config,
    headnodes: headnodes(all: true)
  )

  notifies :restart, 'service[cinder-api]', :immediately
  notifies :restart, 'service[cinder-volume]', :immediately
  notifies :restart, 'service[cinder-scheduler]', :immediately
end
# configure cinder service ends

execute 'wait for cinder to come online' do
  environment os_adminrc
  retries 30
  command 'openstack volume service list'
end

execute 'create ceph cinder backend type' do
  environment os_adminrc
  retries 3
  command <<-DOC
    openstack volume type create ceph
  DOC
  not_if 'openstack volume type show ceph'
end

execute 'set ceph backend properties' do
  environment os_adminrc
  retries 3
  command <<-DOC
    openstack volume type set ceph --property volume_backend_name=ceph
  DOC
  not_if 'openstack volume type show ceph -c properties -f value | grep ceph'
end
