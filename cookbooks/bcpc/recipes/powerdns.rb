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
      make_config('web-pdns-password', secure_password)
      make_config('powerdns-update-timestamp', Time.now.to_i)
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
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot -e "CREATE DATABASE #{node['bcpc']['dbname']['pdns']} CHARACTER SET utf8 COLLATE utf8_general_ci;"
          mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
          mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
          mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
          mysql -uroot -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
          mysql -uroot -e "FLUSH PRIVILEGES;"
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
      self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['pdns']}\"' | grep -q \"#{node['bcpc']['dbname']['pdns']}\" >/dev/null" }
  end

  ruby_block "powerdns-table-keystone_project" do
    block do
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
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
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"keystone_project\"' | grep -q \"keystone_project\" >/dev/null" }
  end

  ruby_block "powerdns-table-domains" do
    block do
      reverse_fixed_zone = node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr'])
      reverse_float_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
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
          INSERT INTO domains (name, type) values ('#{node['bcpc']['cluster_domain']}', 'MASTER');
          INSERT INTO domains (name, type) values ('#{reverse_float_zone}', 'MASTER');
          INSERT INTO domains (name, type) values ('#{reverse_fixed_zone}', 'MASTER');
          CREATE UNIQUE INDEX dom_name_index ON domains(name);
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
      self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"domains\"' | grep -q \"domains\" >/dev/null" }
  end

ruby_block "powerdns-function-ip4_to_ptr_name" do
  block do
    %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
        mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
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
  not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"ip4_to_ptr_name\" >/dev/null" }
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

  ruby_block "powerdns-table-records" do
    block do
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
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
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records\"' | grep -q \"records\" >/dev/null" }
  end

  ruby_block "powerdns-table-supermasters" do
    block do
      %x[ export MYSQL_PWD=#{get_config('mysql-root-password')};
          mysql -uroot #{node['bcpc']['dbname']['pdns']} <<-EOH
          CREATE TABLE IF NOT EXISTS supermasters (
              ip VARCHAR(64) NOT NULL,
              nameserver VARCHAR(255) NOT NULL,
              account VARCHAR(40) DEFAULT NULL
          );
          CREATE UNIQUE INDEX ip_nameserver ON supermasters(ip, nameserver);
      ]
      self.notifies :restart, resources(:service => "pdns"), :delayed
      self.resolve_notification_references
    end
    not_if { system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"supermasters\"' | grep -q \"supermasters\" >/dev/null" }
  end

  # Setup PowerDNS supermaster if we are a slave
  supermaster_records_file = "/tmp/powerdns_generate_supermaster_records.sql"
  template supermaster_records_file do
    source 'powerdns_generate_supermaster_records.sql.erb'
    owner 'root'
    group 'root'
    mode 00644
    variables({
      :database_name => node['bcpc']['dbname']['pdns'],
      :master        => node['bcpc']['dns']['master']
    })
    notifies :run, 'ruby_block[powerdns-load-supermaster-records]', :immediately
  end

  ruby_block "powerdns-load-supermaster-records" do
    block do
      system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot #{node['bcpc']['dbname']['pdns']} < #{supermaster_records_file}"
    end
    action :nothing
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
      :all_servers         => get_all_nodes,
      :float_cidr          => IPAddr.new(node['bcpc']['floating']['available_subnet']),
      :database_name       => node['bcpc']['dbname']['pdns'],
      :cluster_domain      => node['bcpc']['cluster_domain'],
      :floating_vip        => node['bcpc']['floating']['vip'],
      :management_vip      => node['bcpc']['management']['vip'],
      :monitoring_vip      => node['bcpc']['monitoring']['vip'],
      :reverse_fixed_zone  => (node['bcpc']['fixed']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['fixed']['cidr'])),
      :reverse_float_zone  => (node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])),
    })
    notifies :run, 'ruby_block[powerdns-load-float-records]', :immediately
  end

  ruby_block "powerdns-load-float-records" do
    block do
      system "MYSQL_PWD=#{get_config('mysql-root-password')} mysql -uroot #{node['bcpc']['dbname']['pdns']} < #{float_records_file}"
    end
    action :nothing
  end

  # these files are added by the pdns-server package and will conflict with
  # our config file
  %w{/etc/powerdns/bindbackend.conf /etc/powerdns/pdns.d/pdns.local.gmysql /etc/powerdns/pdns.d/pdns.local.conf /etc/powerdns/pdns.d/pdns.simplebind.conf}.each do |pdns_file|
    file pdns_file do
      action :delete
      notifies :restart, "service[pdns]", :delayed
    end
  end

  template "/etc/powerdns/pdns.d/pdns.local.gmysql.conf" do
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
