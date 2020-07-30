# Cookbook:: bcpc
# Recipe:: powerdns
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

require 'ipaddress'

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

package %w(pdns-server pdns-backend-mysql)
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
serial = Time.now.to_i
email = node['bcpc']['keystone']['admin']['email'].tr('@', '.')
networks = node['bcpc']['neutron']['networks'].dup

# expand subnet ip allocations

networks.each do |network|
  %w(fixed float).each do |type|
    network[type].fetch('subnets', []).each do |subnet|
      subnet['allocation'] = IPAddress(subnet['allocation'])
    end
  end
end

# create the forward zone for the cloud domain
begin
  zone = node['bcpc']['cloud']['domain']
  zone_file = "#{Chef::Config[:file_cache_path]}/#{zone}.zone"

  template zone_file do
    source 'powerdns/zone.erb'
    variables(
      email: email,
      serial: serial,
      networks: networks
    )
    not_if "pdnsutil list-all-zones | grep -w #{zone}"
  end

  execute 'load zone' do
    command <<-EOH
      pdnsutil load-zone #{zone} #{zone_file}
    EOH
    not_if "pdnsutil list-all-zones | grep -w #{zone}"
  end
end

# create the reverse zone for each subnet
begin
  networks.each do |network|
    %w(fixed float).each do |type|
      next unless network[type]['dns-zones']['create']

      network[type].fetch('subnets', []).each do |subnet|
        zones = cidr_to_reverse_zones(subnet['allocation'])

        zones.each do |z|
          domain = z['zone']
          zone_file = "#{Chef::Config[:file_cache_path]}/#{domain}.zone"

          template zone_file do
            source 'powerdns/reverse-zone.erb'
            variables(
              zone: z,
              email: email,
              serial: serial,
              fqdn_prefix: network[type]['dns-zones']['fqdn-prefix']
            )
            not_if "pdnsutil list-all-zones | grep -w #{domain}"
          end

          execute 'load reverse zone' do
            command <<-EOH
              pdnsutil load-zone #{domain} #{zone_file}
            EOH
            not_if "pdnsutil list-all-zones | grep -w #{domain}"
          end
        end
      end
    end
  end
end

# install catalog-zone-manage
cookbook_file '/usr/local/sbin/catalog-zone-manage' do
  source 'powerdns/catalog-zone-manage.py'
  mode '0755'
end

directory '/usr/local/lib/catalog-zone' do
  action :create
end

cookbook_file '/usr/local/lib/catalog-zone/zone.j2' do
  source 'powerdns/catalog-zone.j2'
end

directory '/usr/local/etc/catalog-zone' do
  action :create
end

template '/usr/local/etc/catalog-zone/catalog-zone.conf' do
  source 'powerdns/catalog-zone.conf.erb'

  zone = "catalog.#{node['bcpc']['cloud']['domain']}"

  variables(
    zone: zone,
    zone_file: "#{Chef::Config[:file_cache_path]}/#{zone}.zone",
    zone_template: '/usr/local/lib/catalog-zone/zone.j2'
  )
end

# create/synchronize the catalog zone
execute 'sync catalog zone' do
  command '/usr/local/sbin/catalog-zone-manage --sync'
end
