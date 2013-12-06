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

include_recipe "bcpc::nova-head"

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

ruby_block "powerdns-database-creation" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node[:bcpc][:pdns_dbname]}\"' | grep -q \"#{node[:bcpc][:pdns_dbname]}\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node[:bcpc][:pdns_dbname]} CHARACTER SET utf8 COLLATE utf8_general_ci;"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node[:bcpc][:pdns_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node[:bcpc][:pdns_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node[:bcpc][:nova_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node[:bcpc][:nova_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-domains" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"domains_static\"' | grep -q \"domains_static\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE TABLE IF NOT EXISTS domains_static (
                    id INT auto_increment,
                    name VARCHAR(255) NOT NULL,
                    master VARCHAR(128) DEFAULT NULL,
                    last_check INT DEFAULT NULL,
                    type VARCHAR(6) NOT NULL,
                    notified_serial INT DEFAULT NULL,
                    account VARCHAR(40) DEFAULT NULL,
                    primary key (id)
                );
                INSERT INTO domains_static (name, type) values ('#{node[:bcpc][:domain_name]}', 'NATIVE');
                INSERT INTO domains_static (name, type) values ('#{node[:bcpc][:floating][:reverse_dns_zone]}', 'NATIVE');
                CREATE UNIQUE INDEX dom_name_index ON domains_static(name);
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_static\"' | grep -q \"records_static\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                    CREATE TABLE IF NOT EXISTS records_static (
                        id INT auto_increment,
                        domain_id INT DEFAULT NULL,
                        name VARCHAR(255) DEFAULT NULL,
                        type VARCHAR(6) DEFAULT NULL,
                        content VARCHAR(255) DEFAULT NULL,
                        ttl INT DEFAULT NULL,
                        prio INT DEFAULT NULL,
                        change_date INT DEFAULT NULL,
                        primary key(id)
                    );
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','localhost root@#{node[:bcpc][:domain_name]} 1','SOA',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','#{node[:bcpc][:management][:vip]}','NS',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','#{node[:bcpc][:management][:vip]}','A',300,NULL);
                    
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:floating][:reverse_dns_zone]}'),'#{node[:bcpc][:floating][:reverse_dns_zone]}', '#{node[:bcpc][:floating][:reverse_dns_zone]} root@#{node[:bcpc][:domain_name]} 1','SOA',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:floating][:reverse_dns_zone]}'),'#{node[:bcpc][:floating][:reverse_dns_zone]}','#{node[:bcpc][:management][:vip]}','NS',300,NULL);
                    
                    CREATE INDEX rec_name_index ON records_static(name);
                    CREATE INDEX nametype_index ON records_static(name,type);
                    CREATE INDEX domain_id ON records_static(domain_id);
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-function-dns-name" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"dns_name\" AND db = \"#{node[:bcpc][:pdns_dbname]}\";' \"#{node[:bcpc][:pdns_dbname]}\" | grep -q \"dns_name\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                delimiter //
                CREATE FUNCTION dns_name (tenant VARCHAR(64) CHARACTER SET latin1) RETURNS VARCHAR(64)
                COMMENT 'Returns the project name in a DNS acceptable format. Roughly RFC 1035.'
                DETERMINISTIC
                BEGIN
                  SELECT LOWER(tenant) INTO tenant;
                  SELECT REPLACE(tenant, '&', 'and') INTO tenant;
                  SELECT REPLACE(tenant, '_', '-') INTO tenant;
                  SELECT REPLACE(tenant, ' ', '-') INTO tenant;
                  RETURN tenant;
                END//
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-function-ip4_to_ptr_name" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node[:bcpc][:pdns_dbname]}\";' \"#{node[:bcpc][:pdns_dbname]}\" | grep -q \"ip4_to_ptr_name\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
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
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-domains-view" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"domains\"' | grep -q \"domains\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE OR REPLACE VIEW domains AS
                    SELECT id,name,master,last_check,type,notified_serial,account FROM domains_static UNION
                    SELECT
                        # rank each project to create an ID and add the maximum ID from the static table
                        (SELECT COUNT(*) FROM keystone.project WHERE y.id <= id) + (SELECT MAX(id) FROM domains_static) AS id,
                        CONCAT(CONCAT(dns_name(y.name), '.'),'#{node[:bcpc][:domain_name]}') AS name,
                        NULL AS master,
                        NULL AS last_check,
                        'NATIVE' AS type,
                        NULL AS notified_serial,
                        NULL AS account
                        FROM keystone.project y;
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records_forward-view" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_forward\"' | grep -q \"records_forward\""
        if not $?.success? then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE OR REPLACE VIEW records_forward AS
                    SELECT id,domain_id,name,type,content,ttl,prio,change_date FROM records_static UNION  
                    # assume we only have 500 or less static records
                    SELECT domains.id+500 AS id, domains.id AS domain_id, domains.name AS name, 'NS' AS type, '#{node[:bcpc][:management][:vip]}' AS content, 300 AS ttl, NULL AS prio, NULL AS change_date FROM domains WHERE id > (SELECT MAX(id) FROM domains_static) UNION
                    # assume we only have 250 or less static domains
                    SELECT domains.id+750 AS id, domains.id AS domain_id, domains.name AS name, 'SOA' AS type, 'localhost root@#{node[:bcpc][:domain_name]} 1' AS content, 300 AS ttl, NULL AS prio, NULL AS change_date FROM domains WHERE id > (SELECT MAX(id) FROM domains_static) UNION
                    # again, assume we only have 250 or less static domains
                    SELECT nova.instances.id+10000 AS id,
                        # query the domain ID from the domains view
                        (SELECT id FROM domains WHERE name=CONCAT(CONCAT((SELECT dns_name(name) FROM keystone.project WHERE id = nova.instances.project_id),
                                                                  '.'),'#{node[:bcpc][:domain_name]}')) AS domain_id,
                        # create the FQDN of the record
                        CONCAT(nova.instances.hostname,
                          CONCAT('.',
                            CONCAT((SELECT dns_name(name) FROM keystone.project WHERE id = nova.instances.project_id),
                              CONCAT('.','#{node[:bcpc][:domain_name]}')))) AS name,
                        'A' AS type,
                        nova.floating_ips.address AS content,
                        300 AS ttl,
                        NULL AS type,
                        NULL AS change_date FROM nova.instances, nova.fixed_ips, nova.floating_ips
                        WHERE nova.instances.uuid = nova.fixed_ips.instance_uuid AND nova.floating_ips.fixed_ip_id = nova.fixed_ips.id;
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records_reverse-view" do
    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_reverse\"' | grep -q \"records_reverse\""
        if not $?.success? then

            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                create or replace view records_reverse as
                select r.id * -1 as id, d.id as domain_id,
                      ip4_to_ptr_name(r.content) as name,
                      'PTR' as type, r.name as content, r.ttl, r.prio, r.change_date
                from records_forward r, domains d
                where r.type='A' 
                  and d.name = '#{node[:bcpc][:floating][:reverse_dns_zone]}'
                  and ip4_to_ptr_name(r.content) like '%.#{node[:bcpc][:floating][:reverse_dns_zone]}';

            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references

        end
    end
end


ruby_block "powerdns-table-records-view" do

    block do
        system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records\"' | grep -q \"records\""
        if not $?.success? then

            %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
              create or replace view records as
                select id, domain_id, name, type, content, ttl, prio, change_date from records_forward
                union all
                select id, domain_id, name, type, content, ttl, prio, change_date from records_reverse;
            ]

            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end

    end

end

get_all_nodes.each do |server|
    ruby_block "create-dns-entry-#{server['hostname']}" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{server['hostname']}.#{node[:bcpc][:domain_name]}\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{server['hostname']}.#{node[:bcpc][:domain_name]}','#{server['bcpc']['management']['ip']}','A',300,NULL);
                ]
            end
        end
    end
end

%w{openstack kibana graphite zabbix}.each do |static|
    ruby_block "create-management-dns-entry-#{static}" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node[:bcpc][:domain_name]}\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{static}.#{node[:bcpc][:domain_name]}','#{node[:bcpc][:management][:vip]}','A',300,NULL);
                ]
            end
        end
    end
end

%w{s3}.each do |static|
    ruby_block "create-floating-dns-entry-#{static}" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node[:bcpc][:domain_name]}\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{static}.#{node[:bcpc][:domain_name]}','#{node[:bcpc][:floating][:vip]}','A',300,NULL);
                ]
            end
        end
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
    action [ :enable, :start ]
end
