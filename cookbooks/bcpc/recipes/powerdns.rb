#
# Cookbook Name:: bcpc
# Recipe:: powerdns
#
# Copyright 2013, Bloomberg Finance L.P.
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

return unless node['bcpc']['enabled']['dns']

require 'ipaddr'

  %w{pdns-server pdns-backend-mysql}.each do |pkg|
    package pkg do
      action :install
    end
  end

make_config('pdns-db-user', 'pdns')
make_config('pdns-db-password', secure_password)
make_config('pdns-web-password', secure_password)
make_config('pdns-update-timestamp', Time.now.to_i)

pdns_db = node['bcpc']['dbname']['pdns']
nova_db = node['bcpc']['dbname']['nova']
pdns_db_user = get_config('pdns-db-user')
pdns_db_password = get_config('pdns-db-password')

# create pdns database starts
#
template '/tmp/pdns-db.sql' do
  source 'pdns/pdns-db.sql.erb'
  variables(
    'pdns_db' => pdns_db,
    'nova_db' => nova_db,
    'pdns_db_user' => pdns_db_user,
    'pdns_db_password' => pdns_db_password
  )
  notifies :run, 'execute[create-update-pdns-database]', :immediately
end

execute 'create-update-pdns-database' do
  environment ({'MYSQL_PWD' => mysql_root_password})
  action :nothing
  command "mysql -u #{mysql_root_user} < /tmp/pdns-db.sql"
end
# create pdns database ends


include_recipe 'bcpc::packages_powerdns'

template '/etc/powerdns/pdns.conf' do
  source 'pdns.conf.erb'
  owner 'root'
  group 'root'
  mode 00600
  notifies :restart, 'service[pdns]', :delayed
end

ruby_block "powerdns-table-domains-cluster-domain" do
  block do
    %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
        mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
        INSERT INTO domains (name, type) values ('#{ node['bcpc']['cluster_domain'] }', 'NATIVE');
    ]
    self.notifies :restart, resources(:service => "pdns"), :delayed
    self.resolve_notification_references
  end
  only_if {
    %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{ node['bcpc']['cluster_domain'] }\"' ].to_i.zero?
  }
end

rev_guest_network_zones = []
node['bcpc']['guest_networks'].each do |network|

  network.subnets.each do |subnet|

    db = node['bcpc']['dbname']['pdns']
    rev_zone = calc_reverse_dns_zone(subnet['cidr']).first
    rev_guest_network_zones.push(rev_zone)

    execute "add #{network['name']} #{subnet['cidr']} reversed zone" do
      environment ({'MYSQL_PWD' => mysql_root_password})

      command <<-EOH
        mysql -u root #{db} -e \
          "INSERT INTO domains (name, type) values ('#{rev_zone}', 'NATIVE');"
      EOH

      not_if "mysql -u root -e 'select name from pdns.domains' | grep -w #{rev_zone}"

      notifies :restart, 'service[pdns]', :delayed
    end

  end

end

reverse_float_zone.each do |zone|
  ruby_block "powerdns-table-domains-reverse-float-zone-#{zone}" do
    block do
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
          INSERT INTO domains (name, type) values ('#{zone}', 'NATIVE');
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
      self.resolve_notification_references
    end
    only_if {
      %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{zone}\"' ].to_i.zero?
    }
  end

end

  reverse_fixed_zones = []
  reverse_fixed_zone = node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr']).first
  reverse_fixed_zones.push(reverse_fixed_zone)

  reverse_float_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])
  management_zone = calc_reverse_dns_zone(node['bcpc']['management']['cidr'])

  # Reverse fixed zone is assumed to be classful.
  ruby_block "powerdns-table-domains-reverse-fixed-zone" do
    block do
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
          INSERT INTO domains (name, type) values ('#{zone}', 'NATIVE');
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
      self.resolve_notification_references
    end
    only_if {
      %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{zone}\"' ].to_i.zero?
    }
  end
end

  node['bcpc'].fetch('additional_fixed',{}).each{ |id,network|

    reversed_zone = calc_reverse_dns_zone(network['cidr']).first
    reverse_fixed_zones.push(reversed_zone)

    ruby_block "powerdns reverse #{id} zone" do
      block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
            INSERT INTO domains (name, type) values ('#{ reversed_zone }', 'NATIVE');
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
      only_if {
        %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{ reversed_zone }\"' ].to_i.zero?
      }
    end

  }

  reverse_float_zone.each do |zone|
    ruby_block "powerdns-table-domains-reverse-float-zone-#{zone}" do
      block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
            INSERT INTO domains (name, type) values ('#{zone}', 'NATIVE');
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
      only_if {
        %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{zone}\"' ].to_i.zero?
      }
    end
  end

  management_zone.each do |zone|
    ruby_block "powerdns-table-domains-management-zone-#{zone}" do
      block do
        %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
            mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
            INSERT INTO domains (name, type) values ('#{zone}', 'NATIVE');
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
      only_if {
        %x[ MYSQL_PWD=#{get_config('mysql-root-password')} mysql -B --skip-column-names -uroot -e 'SELECT count(*) FROM pdns.domains WHERE name = \"#{zone}\"' ].to_i.zero?
      }
    end
  end
  not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"ip4_to_ptr_name\" >/dev/null" }
end

# MySQL function to determine the DNS zone a PTR belongs to.
ruby_block 'powerdns-function-get_ptr_domain' do
  block do
    %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
        mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
        delimiter //
        CREATE FUNCTION get_ptr_domain(
        ptr VARCHAR(64) CHARACTER SET latin1,
        octets TINYINT(1))
        RETURNS INT
        COMMENT 'Returns the domain ID the PTR belongs to'
        DETERMINISTIC
        BEGIN
          DECLARE domain_id INT(11);
          SELECT id FROM pdns.domains
          WHERE
          name = (SELECT SUBSTRING_INDEX(
                  SUBSTRING_INDEX(ptr, '.', 6), '.', -6+octets))
                  INTO domain_id;
          RETURN domain_id;
        END//
    ]
    self.notifies :restart, resources(:service => 'pdns'), :delayed
  end
  not_if {
    system "MYSQL_PWD=#{get_config('mysql-root-password')} \
            mysql -uroot -e 'SELECT name FROM mysql.proc
            WHERE name = \"get_ptr_domain\"
            AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \
            \"#{node['bcpc']['dbname']['pdns']}\" \
            | grep -q get_ptr_domain >/dev/null"
  }
end

ruby_block "powerdns-function-dns-name" do
  block do
    %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
        mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
        delimiter //
        CREATE FUNCTION dns_name (tenant VARCHAR(64) CHARACTER SET latin1) RETURNS VARCHAR(64)
        COMMENT 'Returns the project name in a DNS acceptable format. Roughly RFC 1035.'
        DETERMINISTIC
        BEGIN
          SELECT LOWER(tenant) INTO tenant;
          SELECT REPLACE(tenant, '&', 'and') INTO tenant;
          SELECT REPLACE(tenant, '_', '-') INTO tenant;
          SELECT REPLACE(tenant, ' ', '-') INTO tenant;
          SELECT REPLACE(tenant, '.', '-') INTO tenant;
          RETURN tenant;
        END//
    ]
    self.notifies :restart, resources(:service => "pdns"), :delayed
    self.resolve_notification_references
  end
  not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT name FROM mysql.proc WHERE name = \"dns_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"dns_name\" >/dev/null" }
end

# this template replaces pre-seeds DNS entries into a template file to be loaded into MySQL
# fixed IPs require the nova schema to be present in MySQL, so that has been moved to its own template and recipe
dns_records_file = "/tmp/powerdns_generate_dns_records.sql"

# Determine the number of right-most octets to drop for addresses to help
# find the reverse DNS zone name one is part of.
mgmt_octets = calc_octets_to_drop(node['bcpc']['management']['cidr'])

  template float_records_file do
    source "powerdns_generate_float_records.sql.erb"
    owner "root"
    group "root"
    mode 00644
    # result of get_all_nodes is passed in here because Chef can't get context for running Chef::Search::Query#search inside the template generator
    variables(
      lazy {
        {
          :all_servers         => get_all_nodes,
          :float_cidr          => IPAddr.new(node['bcpc']['floating']['available_subnet']),
          :database_name       => node['bcpc']['dbname']['pdns'],
          :cluster_domain      => node['bcpc']['cluster_domain'],
          :management_vip      => node['bcpc']['management']['vip'],
          :monitoring_vip      => node['bcpc']['monitoring']['vip'],
          :reverse_fixed_zones => reverse_fixed_zones,
          :reverse_float_zone  => reverse_float_zone,
          :management_zone     => management_zone,
          :mgmt_octets         => mgmt_octets,
          :float_octets        => float_octets
        }
      }
    }
  )
  notifies :run, 'bash[load powerdns dns records]', :immediately
end

bash "load powerdns dns records" do
  action :nothing

  environment ({'MYSQL_PWD' => mysql_root_password})
  db = node['bcpc']['dbname']['pdns']

  code <<-EOH
    mysql -u root #{db} < #{dns_records_file}
  EOH
end


# these files are added by the pdns-server package and will conflict with
# our config file
%w[
  /etc/powerdns/bindbackend.conf
  /etc/powerdns/pdns.d/pdns.local.gmysql
  /etc/powerdns/pdns.d/pdns.local.conf
  /etc/powerdns/pdns.d/pdns.simplebind.conf
].each do |pdns_file|
  file pdns_file do
    action :delete
    notifies :restart, 'service[pdns]', :delayed
  end
end

template '/etc/powerdns/pdns.d/pdns.local.gmysql.conf' do
  source 'pdns/pdns.local.gmysql.conf.erb'
  owner 'pdns'
  group 'root'
  mode 00640
  notifies :restart, 'service[pdns]', :immediately
end

service 'pdns' do
  action [:enable, :start]
  retries 5
  retry_delay 10
end
