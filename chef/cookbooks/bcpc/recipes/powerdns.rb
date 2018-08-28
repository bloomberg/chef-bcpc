# Cookbook Name:: bcpc
# Recipe:: powerdns
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
  'dbname' => node['bcpc']['powerdns']['db']['dbname'],
  'username' => config['powerdns']['creds']['db']['username'],
  'password' => config['powerdns']['creds']['db']['password'],
}

# create/manage pdns database starts
#
file '/tmp/pdns-create-db.sql' do
  action :nothing
end

template '/tmp/pdns-create-db.sql' do
  source 'powerdns/pdns-create-db.sql.erb'
  variables(
    'db' => database
  )
  notifies :run, 'execute[create pdns database]', :immediately
  not_if "
    user=#{mysqladmin['username']}
    db=#{database['dbname']}
    count=$(mysql -u ${user} ${db} -e 'show tables' | wc -l)
    [ $count -gt 0 ]
  ", environment: { 'MYSQL_PWD' => mysqladmin['password'] }
end

execute 'create pdns database' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])

  command "mysql -u #{mysqladmin['username']} < /tmp/pdns-create-db.sql"

  notifies :delete, 'file[/tmp/pdns-create-db.sql]', :immediately
end
#
# create/manage pdns database ends

package 'pdns-server'
package 'pdns-backend-mysql'
service 'pdns'

# remove default pdns.d directory
directory '/etc/powerdns/pdns.d' do
  action :delete
  recursive true
end

template '/etc/powerdns/pdns.conf' do
  source 'powerdns/pdns.conf.erb'
  variables(
    db: database,
    api_key: config['powerdns']['creds']['api']['key'],
    webserver_password: config['powerdns']['creds']['webserver']['password']
  )
  notifies :restart, 'service[pdns]', :immediately
end

begin
  require 'ipaddress'

  # build an array of network objects that have their fixed cidr
  # information expanded via 'IPAddress' which can be iterated on
  # in the zone.erb template file
  networks = []
  node['bcpc']['neutron']['networks'].each do |network|
    data = { 'name' => network['name'], 'cidrs' => [] }
    network['fixed'].each do |fixed|
      data['cidrs'].push(IPAddress(fixed['cidr']))
    end
    networks.push(data)
  end

  zone = node['bcpc']['cloud']['domain']
  zone_file = "/tmp/#{zone}.zone"

  template zone_file do
    source 'powerdns/zone.erb'

    serial_number = Time.now.strftime('%Y%m%d01')
    admin_email = node['bcpc']['keystone']['admin']['email'].tr('@', '.')

    variables(
      networks: networks,
      admin_email: admin_email,
      serial_number: serial_number
    )

    not_if "pdnsutil list-all-zones | grep #{zone}"
    notifies :run, 'execute[load zone]', :immediately
  end

  execute 'load zone' do
    action :nothing
    command <<-EOH
      pdnsutil load-zone #{zone} #{zone_file}
    EOH
  end
end
