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

if node['bcpc']['enabled']['dns'] then
  require 'ipaddr'

  ruby_block "initialize-powerdns-config" do
    block do
      make_config('mysql-pdns-user', "pdns")
      make_config('mysql-pdns-password', secure_password)
    end
  end

  %w{pdns-server pdns-backend-mysql}.each do |pkg|
    package pkg do
      action :upgrade
    end
  end

  template "/etc/powerdns/pdns.conf" do
      source "pdns.conf.erb"
      owner "root"
      group "root"
      mode 00600
      notifies :restart, "service[pdns]", :delayed
  end

  # this old cron job needs to be removed because it wipes out the contents of the pdns.records table that are seeded by the new template
  cron "powerdns_populate_records" do
    action :delete
  end

  ruby_block "powerdns-database-creation" do
    block do
      system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['pdns']}\"' | grep -q \"#{node['bcpc']['dbname']['pdns']}\""
      if not $?.success? then
        %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['pdns']} CHARACTER SET utf8 COLLATE utf8_general_ci;"
            mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
            mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
            mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
            mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
            mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
    end
  end

  ruby_block "powerdns-table-keystone_project" do
    block do
      system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"keystone_project\"' | grep -q \"keystone_project\""
      if not $?.success? then
        %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
            CREATE TABLE IF NOT EXISTS keystone_project (
                id VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL
            );
            CREATE UNIQUE INDEX keystone_project_name ON keystone_project(name);
            CREATE UNIQUE INDEX keystone_project_id on keystone_project(id);
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
    end
  end

  ruby_block "powerdns-table-domains" do
    block do
      reverse_fixed_zone = node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr'])
      reverse_float_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

      system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"domains\"' | grep -q \"domains\""
      if not $?.success? then
        %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
            CREATE TABLE IF NOT EXISTS domains (
                id INT auto_increment,
                name VARCHAR(255) NOT NULL,
                master VARCHAR(128) DEFAULT NULL,
                last_check INT DEFAULT NULL,
                type VARCHAR(6) NOT NULL,
                notified_serial INT DEFAULT NULL,
                account VARCHAR(40) DEFAULT NULL,
                primary key (id)
            );
            INSERT INTO domains (name, type) values ('#{node['bcpc']['domain_name']}', 'NATIVE');
            INSERT INTO domains (name, type) values ('#{reverse_float_zone}', 'NATIVE');
            INSERT INTO domains (name, type) values ('#{reverse_fixed_zone}', 'NATIVE');
            CREATE UNIQUE INDEX dom_name_index ON domains(name);
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
    end
  end

ruby_block "powerdns-function-ip4_to_ptr_name" do
  block do
    system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"ip4_to_ptr_name\""
    if not $?.success?
      %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
          delimiter //
          CREATE FUNCTION ip4_to_ptr_name(ip4 VARCHAR(64) CHARACTER SET latin1) RETURNS VARCHAR(64)
          COMMENT 'Returns the reversed IP with .in-addr.arpa appended, suitable for use in the name column of PTR records.'
          DETERMINISTIC
          BEGIN
          return concat_ws( '.',  SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 4), '.', -1),
                                  SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 3), '.', -1),
                                  SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 2), '.', -1),
                                  SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 1), '.', -1), 'in-addr.arpa');
          END//
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
    end
  end
end

  ruby_block "powerdns-function-dns-name" do
    block do
      system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"dns_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"dns_name\""
      if not $?.success? then
        %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
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
    end
  end

  ruby_block "powerdns-table-records" do
    block do
      system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records\"' | grep -q \"records\""
      if not $?.success? then
        %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
            CREATE TABLE IF NOT EXISTS records (
                id INT auto_increment,
                domain_id INT DEFAULT NULL,
                name VARCHAR(255) DEFAULT NULL,
                type VARCHAR(6) DEFAULT NULL,
                content VARCHAR(255) DEFAULT NULL,
                ttl INT DEFAULT 300,
                prio INT DEFAULT NULL,
                change_date INT DEFAULT NULL,
                bcpc_record_type VARCHAR(32),
                primary key(id)
            );
            CREATE INDEX rec_name_index ON records(name);
            CREATE INDEX nametype_index ON records(name,type);
            CREATE INDEX domain_id ON records(domain_id);
            -- this unique index exists in order to facilitate the use of INSERT INTO ON DUPLICATE KEY UPDATE for doing non-destructive inserts/updates
            -- change_date is intentionally not included so that it will not be considered as part of the record itself when determining uniqueness
            -- prio is also not included because it is NULL in all cases for us and this apparently confuses MySQL into thinking that the INSERT is always unique when it's not
            CREATE UNIQUE INDEX idx_records_all_fields ON records (domain_id, name, type, content, ttl, bcpc_record_type);
        ]
        self.notifies :restart, resources(:service => "pdns"), :delayed
        self.resolve_notification_references
      end
    end
  end

  # this template replaces several old ruby_block resources and pre-seeds static and float entries into a template file to be loaded into MySQL
  # fixed IPs require the nova schema to be present in MySQL, so that has been moved to its own template and recipe
  float_records_file = "/tmp/powerdns_generate_float_records.sql"

  template float_records_file do
    source "powerdns_generate_float_records.sql.erb"
    owner "root"
    group "root"
    mode 00644
    # result of get_all_nodes is passed in here because Chef can't get context for running Chef::Search::Query#search inside the template generator
    variables({
      :all_servers               => get_all_nodes,
      :float_cidr                => IPAddr.new(node['bcpc']['floating']['available_subnet']),
      :database_name             => node['bcpc']['dbname']['pdns'],
      :domain_name               => node['bcpc']['domain_name'],
      :floating_vip              => node['bcpc']['floating']['vip'],
      :management_vip            => node['bcpc']['management']['vip'],
      :management_monitoring_vip => node['bcpc']['management']['monitoring']['vip'],
      :update_timestamp          => Time.now.to_i,
      :reverse_fixed_zone        => (node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr'])),
      :reverse_float_zone        => (node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])),
    })
  end

  ruby_block "powerdns-load-float-records" do
    block do
      system "mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} < #{float_records_file}"
    end
  end

  template "/etc/powerdns/pdns.d/pdns.local.gmysql" do
    source "pdns.local.gmysql.erb"
    owner "pdns"
    group "root"
    mode 00640
    notifies :restart, "service[pdns]", :immediately
  end

  service "pdns" do
    action [:enable, :start]
    retries 5
    retry_delay 10
  end
end
