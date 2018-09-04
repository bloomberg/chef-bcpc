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

# DNS forward zone creation/population
#
serial = Time.now.strftime('%Y%m%d01')
email = node['bcpc']['keystone']['admin']['email'].tr('@', '.')
networks = node['bcpc']['neutron']['networks']

begin
  zone = node['bcpc']['cloud']['domain']
  zone_file = "#{Chef::Config[:file_cache_path]}/#{zone}.zone"

  # create dns zone for the cloud domain and setup forward lookups for
  # fixed and float ip ranges
  template zone_file do
    source 'powerdns/zone.erb'
    variables(
      email: email,
      serial: serial,
      networks: networks
    )
  end

  execute 'load zone' do
    command <<-EOH
      pdnsutil load-zone #{zone} #{zone_file}
    EOH
    not_if "pdnsutil list-all-zones | grep #{zone}"
  end
end

# DNS reverse zone for each fixed/float network
#
begin
  networks.each do |network|
    %w(fixed float).each do |type|
      network.fetch(type, []).each do |subnet|
        next unless subnet.key?('dns') && subnet['dns'].key?('reverse_zone')

        reverse_zone = subnet['dns']['reverse_zone']
        reverse_zone_file = "#{Chef::Config[:file_cache_path]}/#{reverse_zone}.zone"

        template reverse_zone_file do
          source 'powerdns/reverse-zone.erb'
          variables(
            email: email,
            serial: serial,
            subnet: subnet,
            reverse_zone: reverse_zone,
            hostname_prefix: subnet['dns']['hostname_prefix']
          )
          not_if "pdnsutil list-all-zones | grep #{reverse_zone}"
        end

        execute 'load reverse zone' do
          command <<-EOH
            pdnsutil load-zone #{reverse_zone} #{reverse_zone_file}
          EOH
          not_if "pdnsutil list-all-zones | grep #{reverse_zone}"
        end
      end
    end
  end
end
