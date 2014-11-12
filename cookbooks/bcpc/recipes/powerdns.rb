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
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['pdns']}\"' | grep -q \"#{node['bcpc']['dbname']['pdns']}\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['pdns']} CHARACTER SET utf8 COLLATE utf8_general_ci;"
                    mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                    mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['pdns']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                    mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                    mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['nova']}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-pdns-password')}';"
                    mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
                ]
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end
        end
    end

    ruby_block "powerdns-table-domains" do
        block do

            reverse_dns_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"domains_static\"' | grep -q \"domains_static\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
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
                    INSERT INTO domains_static (name, type) values ('#{node['bcpc']['domain_name']}', 'NATIVE');
                    INSERT INTO domains_static (name, type) values ('#{reverse_dns_zone}', 'NATIVE');
                    CREATE UNIQUE INDEX dom_name_index ON domains_static(name);
                ]
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end
        end
    end

    ruby_block "powerdns-table-records" do
        block do

            reverse_dns_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records_static\"' | grep -q \"records_static\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
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
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node['bcpc']['domain_name']}'),'#{node['bcpc']['domain_name']}','#{node['bcpc']['management']['vip']}','NS',300,NULL);
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node['bcpc']['domain_name']}'),'#{node['bcpc']['domain_name']}','#{node['bcpc']['management']['vip']}','A',300,NULL);
                        
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{reverse_dns_zone}'),'#{reverse_dns_zone}','#{node['bcpc']['management']['vip']}','NS',300,NULL);
                        
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
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end
        end
    end

    ruby_block "powerdns-function-ip4_to_ptr_name" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"ip4_to_ptr_name\""
            if not $?.success? then
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
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end
        end
    end

    ruby_block "powerdns-table-domains-view" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"domains\"' | grep -q \"domains\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                    CREATE OR REPLACE VIEW domains AS
                        SELECT id,name,master,last_check,type,notified_serial,account FROM domains_static UNION
                        SELECT
                            # rank each project to create an ID and add the maximum ID from the static table
                            (SELECT COUNT(*) FROM keystone.project WHERE y.id <= id) + (SELECT MAX(id) FROM domains_static) AS id,
                            CONCAT(CONCAT(dns_name(y.name), '.'),'#{node['bcpc']['domain_name']}') AS name,
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
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records_forward\"' | grep -q \"records_forward\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                    CREATE OR REPLACE VIEW records_forward AS
                        /* SOA Forward */
                        select -1 as id ,
                            (SELECT id FROM domains_static WHERE name='#{node['bcpc']['domain_name']}') as domain_id,
                            '#{node['bcpc']['domain_name']}' as name,
                            'SOA' as type,
                            concat('#{node['bcpc']['domain_name']} root.#{node['bcpc']['domain_name']} ', (select cast(unix_timestamp(greatest(coalesce(max(created_at), 0), coalesce(max(updated_at), 0), coalesce(max(deleted_at), 0))) as unsigned integer) from nova.floating_ips) ) as content,
                             300 as ttl, NULL as prio,
                             NULL as change_date
                        union
                        SELECT id,domain_id,name,type,content,ttl,prio,change_date FROM records_static UNION  
                        # assume we only have 500 or less static records
                        SELECT domains.id+500 AS id, domains.id AS domain_id, domains.name AS name, 'NS' AS type, '#{node['bcpc']['management']['vip']}' AS content, 300 AS ttl, NULL AS prio, NULL AS change_date FROM domains WHERE id > (SELECT MAX(id) FROM domains_static) UNION
                        # assume we only have 250 or less static domains
                        SELECT domains.id+750 AS id, domains.id AS domain_id, domains.name AS name, 'SOA' AS type, concat('#{node['bcpc']['domain_name']} root.#{node['bcpc']['domain_name']} ', (select cast(unix_timestamp(greatest(coalesce(max(created_at), 0), coalesce(max(updated_at), 0), coalesce(max(deleted_at), 0))) as unsigned integer) from nova.floating_ips) ) AS content, 300 AS ttl, NULL AS prio, NULL AS change_date FROM domains WHERE id > (SELECT MAX(id) FROM domains_static) UNION
                        # again, assume we only have 250 or less static domains
                        SELECT nova.instances.id+10000 AS id,
                            # query the domain ID from the domains view
                            (SELECT id FROM domains WHERE name=CONCAT(CONCAT((SELECT dns_name(name) FROM keystone.project WHERE id = nova.instances.project_id),
                                                                      '.'),'#{node['bcpc']['domain_name']}')) AS domain_id,
                            # create the FQDN of the record
                            CONCAT(nova.instances.hostname,
                              CONCAT('.',
                                CONCAT((SELECT dns_name(name) FROM keystone.project WHERE id = nova.instances.project_id),
                                  CONCAT('.','#{node['bcpc']['domain_name']}')))) AS name,
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

            reverse_dns_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records_reverse\"' | grep -q \"records_reverse\""
            if not $?.success? then

                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                    create or replace view records_reverse as
                    /* SOA reverse */
                    select -2 as id,
                        (SELECT id FROM domains_static WHERE name='#{reverse_dns_zone}') as domain_id,
                        '#{reverse_dns_zone}' as name, 
                        'SOA' as type,
                        concat('#{node['bcpc']['domain_name']} root.#{node['bcpc']['domain_name']} ', (select cast(unix_timestamp(greatest(coalesce(max(created_at), 0), coalesce(max(updated_at), 0), coalesce(max(deleted_at), 0))) as unsigned integer) from nova.floating_ips) ) as content,
                        300 as ttl, NULL as prio,
                        NULL as change_date
                    union all
                    select r.id * -1 as id, d.id as domain_id,
                          ip4_to_ptr_name(r.content) as name,
                          'PTR' as type, r.name as content, r.ttl, r.prio, r.change_date
                    from records_forward r, domains d
                    where r.type='A' 
                      and d.name = '#{reverse_dns_zone}'
                      and ip4_to_ptr_name(r.content) like '%.#{reverse_dns_zone}';

                ]
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references

            end
        end
    end


    ruby_block "powerdns-table-records-all-view" do

        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node['bcpc']['dbname']['pdns']}\" AND TABLE_NAME=\"records_all\"' | grep -q \"records_all\""
            if not $?.success? then

                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                  create or replace view records_all as
                    select id, domain_id, name, type, content, ttl, prio, change_date from records_forward
                    union all
                    select id, domain_id, name, type, content, ttl, prio, change_date from records_reverse;
                ]

                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end

        end

    end

    ruby_block "powerdns-table-records" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE table_name = \"records\" AND table_schema = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"records\""
            if not $?.success? then

                # Using this as a guide: http://doc.powerdns.com/html/generic-mypgsql-backends.html
                # We don't currently have all the fields in the table, but it doesn't seem to cause a problem so
                # far. I'm not changing the schema we have now. These might be important if we upgrade PDNS or
                # need to use other features.

                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                  create table records( 
                    id          bigint(20) not null default 0,
                    domain_id   bigint(20),
                    name        varchar(341),
                    type        varchar(6),
                    content     varchar(341),
                    ttl         bigint(20),
                    prio        int(11),
                    change_date bigint unsigned
                  );
                  
                  /* Use the indexes from the doc. */
                  CREATE INDEX nametype_index ON records(name,type);
                  CREATE INDEX domain_id ON records(domain_id);

                ]
            end
        end
    end

    ruby_block "powerdns-function-populate_records" do
        block do
            system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT name FROM mysql.proc WHERE name = \"populate_records\" AND db = \"#{node['bcpc']['dbname']['pdns']}\";' \"#{node['bcpc']['dbname']['pdns']}\" | grep -q \"populate_records\""
            if not $?.success? then
                %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                    delimiter //
                    CREATE PROCEDURE populate_records () 
                    COMMENT 'Persists dynamic DNS records from records_all view into records table'
                    BEGIN

                        start transaction;
                            delete from records;
                            insert into records(id, domain_id, name, type, content, ttl, prio, change_date)
                            select id, domain_id, name, type, content, ttl, prio, change_date
                            from records_all;
                        commit;

                    END//
                ]
                self.notifies :restart, "service[pdns]", :delayed
                self.resolve_notification_references
            end
        end
    end

    # This triggers populate_records() to populate records from records_all. If this doesn't run, the dynamic 
    # bits of DNS will get stale. The command is guarded by if_vip so that it is present on all head 
    # nodes should one go away, but it will only execute if the current node is the VIP.
    cron "powerdns_populate_records" do
        minute "*"
        hour "*"
        weekday "*"
        command "if [ -n \"$(/usr/local/bin/if_vip echo Y)\" ] ; then echo \"call populate_records();\" | mysql -updns -p#{get_config('mysql-pdns-password')} #{node['bcpc']['dbname']['pdns']} 2>&1 > /var/log/pdns_populate_records.last.log ; fi"
    end

    get_all_nodes.each do |server|
        ruby_block "create-dns-entry-#{server['hostname']}" do
            block do
                system "mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} -e 'SELECT name FROM records_static' | grep -q \"#{server['hostname']}.#{node['bcpc']['domain_name']}\""
                if not $?.success? then
                    %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                            INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node['bcpc']['domain_name']}'),'#{server['hostname']}.#{node['bcpc']['domain_name']}','#{server['bcpc']['management']['ip']}','A',300,NULL);
                    ]
                end
            end
        end

        ruby_block "create-dns-entry-#{server['hostname']}-shared" do
            block do
                system "mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} -e 'SELECT name FROM records_static' | grep -q \"#{server['hostname']}-shared.#{node['bcpc']['domain_name']}\""
                if not $?.success? then
                    %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                            INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node['bcpc']['domain_name']}'),'#{server['hostname']}-shared.#{node['bcpc']['domain_name']}','#{server['bcpc']['floating']['ip']}','A',300,NULL);
                    ]
                end
            end
        end
    end

    %w{openstack kibana graphite zabbix}.each do |static|
        ruby_block "create-management-dns-entry-#{static}" do
            block do
                system "mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node['bcpc']['domain_name']}\""
                if not $?.success? then
                    %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                            INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node['bcpc']['domain_name']}'),'#{static}.#{node['bcpc']['domain_name']}','#{node['bcpc']['management']['vip']}','A',300,NULL);
                    ]
                end
            end
        end
    end

    %w{s3}.each do |static|
        ruby_block "create-floating-dns-entry-#{static}" do
            block do
                system "mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node['bcpc']['domain_name']}\""
                if not $?.success? then
                    %x[ mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['dbname']['pdns']} <<-EOH
                            INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node['bcpc']['domain_name']}'),'#{static}.#{node['bcpc']['domain_name']}','#{node['bcpc']['floating']['vip']}','A',300,NULL);
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
        action [:enable, :start]
    end

end
