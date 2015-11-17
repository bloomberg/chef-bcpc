#
# Cookbook Name:: bcpc
# Recipe:: zabbix-server
#
# Copyright 2015, Bloomberg Finance L.P.
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

if node['bcpc']['enabled']['monitoring'] then
    include_recipe "bcpc::mysql-monitoring"
    include_recipe "bcpc::apache2"
    include_recipe "bcpc::packages-zabbix"

    ruby_block "initialize-zabbix-config" do
        block do
            make_config('mysql-zabbix-user', "zabbix")
            make_config('mysql-zabbix-password', secure_password)
            make_config('zabbix-admin-user', "admin")
            make_config('zabbix-admin-password', secure_password)
            make_config('zabbix-guest-user', "guest")
            make_config('zabbix-guest-password', secure_password)
        end
    end
    
    # this script removes the old manually compiled Zabbix server installation
    # (being a bit lazy and assuming the presence of the old server binary signals everything
    # is still there)
    bash "clean-up-old-zabbix-server" do
        code <<-EOH
          service zabbix-server stop
          rm -f /usr/local/etc/zabbix_server.conf
          rm -f /usr/local/sbin/zabbix_server
          rm -f /usr/local/share/man/man8/zabbix_server.8
          rm -rf /usr/local/share/zabbix
          rm -rf /usr/local/etc/zabbix_server.conf.d
          rm -f /tmp/zabbix-server.tar.gz
          rm -f /etc/init/zabbix-server.conf
          killall zabbix_server || true
        EOH
        only_if 'test -f /usr/local/sbin/zabbix_server'
    end

    # Package is a soft dependency of zabbix-server
    package "snmp-mibs-downloader" do
        action :upgrade
    end

    %w{zabbix-server-mysql zabbix-frontend-php}.each do |zabbix_package|
      package zabbix_package do
        action :upgrade
        # no-install-recommends used here because zabbix-server-mysql wants to remove
        # Percona packages in favor of non-clustered Oracle MySQL otherwise
        if node['bcpc']['apt']['dpkgopts'][zabbix_package]
          options node['bcpc']['apt']['dpkgopts'][zabbix_package]
        end
      end
    end
    
    # terminate the Zabbix server if this server doesn't hold the monitoring VIP
    # (this is a safeguard to get out of a potential weird state immediately after
    # migrating from compiled Zabbix to packaged Zabbix)
    bash "stop-zabbix-server-if-not-monitoring-vip" do
      code <<-EOH
        if_not_monitoring_vip service zabbix-server stop
      EOH
      not_if "service zabbix-server status | grep -q stop/waiting"
    end

    # disable the sysvinit version from automatic startup
    bash "stop-sysvinit-zabbix-server" do
        code <<-EOH
        /usr/sbin/update-rc.d -f zabbix-server remove
        /etc/init.d/zabbix-server stop
        EOH
    end

    # make package-provided sysvinit script a stub to prevent accidental use
    file "/etc/init.d/zabbix-server" do
        content "exit 0"
        user "root"
        group "root"
        mode "755"
    end

    ruby_block "zabbix-database-creation" do
        block do
            if not system "mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['zabbix']}\"'|grep \"#{node['bcpc']['dbname']['zabbix']}\"" then
                %x[ mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e "CREATE DATABASE #{node['bcpc']['dbname']['zabbix']} CHARACTER SET UTF8;"
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['zabbix']}.* TO '#{get_config('mysql-zabbix-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-zabbix-password')}';"
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e "GRANT ALL ON #{node['bcpc']['dbname']['zabbix']}.* TO '#{get_config('mysql-zabbix-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-zabbix-password')}';"
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} -e "FLUSH PRIVILEGES;"
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} #{node['bcpc']['dbname']['zabbix']} < /usr/share/zabbix-server-mysql/schema.sql
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} #{node['bcpc']['dbname']['zabbix']} < /usr/share/zabbix-server-mysql/images.sql
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} #{node['bcpc']['dbname']['zabbix']} < /usr/share/zabbix-server-mysql/data.sql
                    HASH=`echo -n "#{get_config('zabbix-admin-password')}" | md5sum | awk '{print $1}'`
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} #{node['bcpc']['dbname']['zabbix']} -e "UPDATE users SET passwd=\\"$HASH\\" WHERE alias=\\"#{get_config('zabbix-admin-user')}\\";"
                    HASH=`echo -n "#{get_config('zabbix-guest-password')}" | md5sum | awk '{print $1}'`
                    mysql -uroot -p#{get_config('mysql-monitoring-root-password')} #{node['bcpc']['dbname']['zabbix']} -e "UPDATE users SET passwd=\\"$HASH\\" WHERE alias=\\"#{get_config('zabbix-guest-user')}\\";"
                ]
            end
        end
    end

    template "/etc/zabbix/zabbix_server.conf" do
        source "zabbix_server.conf.erb"
        owner node['bcpc']['zabbix']['user']
        group "root"
        mode 00600
        notifies :restart, "service[zabbix-server]", :delayed
    end

    # Upstart job to replace sysvinit script. This allows nicer interaction with
    # with keepalived. Upstart takes precedence if called by `service`.
    template '/etc/init/zabbix-server.conf' do
      source   'upstart-zabbix-server.conf.erb'
      owner    'root'
      group    'root'
      notifies :restart, 'service[zabbix-server]', :immediately
    end

    # do automatic service startup via the Upstart wrapper
    service 'zabbix-server' do
        action   [:enable, :start]
        provider Chef::Provider::Service::Upstart
    end

    %w{traceroute php5-mysql php5-gd python-requests}.each do |pkg|
        package pkg do
            action :upgrade
        end
    end

    file "/etc/php5/apache2/conf.d/zabbix.ini" do
        action :delete
        notifies :restart, "service[apache2]", :delayed
    end

    template "/etc/zabbix/apache.conf" do
        source "apache-zabbix-global.conf.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
            :php_settings => node['bcpc']['zabbix']['php_settings']
        )
        notifies :restart, "service[apache2]", :delayed
    end

    bash "apache-enable-zabbix-global-conf" do
        user "root"
        code <<-EOH
             a2enconf zabbix
        EOH
        not_if "test -r /etc/apache2/conf-enabled/zabbix.conf"
        notifies :restart, "service[apache2]", :delayed
    end

    template "/etc/zabbix/web/zabbix.conf.php" do
        source "zabbix.conf.php.erb"
        user node['bcpc']['zabbix']['user']
        group "www-data"
        mode 00640
        notifies :restart, "service[apache2]", :delayed
    end

    template "/etc/apache2/sites-available/zabbix-web.conf" do
        source "apache-zabbix-web.conf.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :restart, "service[apache2]", :delayed
    end

    bash "apache-enable-zabbix-web" do
        user "root"
        code <<-EOH
             a2ensite zabbix-web
        EOH
        not_if "test -r /etc/apache2/sites-enabled/zabbix-web.conf"
        notifies :restart, "service[apache2]", :immediate
    end

    cookbook_file "/tmp/python-pyzabbix_0.7.3_all.deb" do
        source "bins/python-pyzabbix_0.7.3_all.deb"
        owner "root"
        mode 00444
    end

    package "python-pyzabbix" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/python-pyzabbix_0.7.3_all.deb"
        action :upgrade
    end

    cookbook_file "/tmp/zabbix_linux_active_template.xml" do
        source "zabbix_linux_active_template.xml"
        owner "root"
        mode 00644
    end

    cookbook_file "/tmp/zabbix_bcpc_templates.xml" do
        source "zabbix_bcpc_templates.xml"
        owner "root"
        mode 00644
    end

    cookbook_file "/usr/local/bin/zabbix_config" do
        source "zabbix_config"
        owner "root"
        mode 00755
    end

    ruby_block "configure_zabbix_templates" do
        block do
            # Ensures no proxy is ever used locally
            %x[export no_proxy="#{node['bcpc']['management']['ip']}";
               zabbix_config http://#{node['bcpc']['management']['ip']}:7777/ #{get_config('zabbix-admin-user')} #{get_config('zabbix-admin-password')}
            ]
        end
    end

    template "/usr/share/zabbix/zabbix-api-auto-discovery" do
        source "zabbix_api_auto_discovery.erb"
        owner "root"
        group "root"
        mode 00750
    end

    ruby_block "zabbix-api-auto-discovery-register" do
        block do
            # Ensures no proxy is ever used locally
            %x[export no_proxy="#{node['bcpc']['management']['ip']}";
               /usr/share/zabbix/zabbix-api-auto-discovery
            ]
        end
    end

    cookbook_file "/tmp/zabbix-mysql-partition-baseline.sql" do
        source "zabbix-mysql-partition-baseline.sql"
        owner "root"
        mode 00644
    end

    template "/tmp/zabbix-mysql-partition-maintenance-all.sql" do
        source "zabbix-mysql-partition-maintenance-all.sql.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
            :storage_retention => node['bcpc']['zabbix']['storage_retention']
        )
    end

    # Create baseline stored procedures to setup partitioning
    ruby_block "zabbix-partition-baseline-setup" do
        block do
            %x[ export MYSQL_PWD=#{get_config('mysql-zabbix-password')};
                mysql -u#{get_config('mysql-zabbix-user')} #{node['bcpc']['dbname']['zabbix']} < /tmp/zabbix-mysql-partition-baseline.sql
            ]
        end
        not_if { system "MYSQL_PWD=#{get_config('mysql-monitoring-root-password')} mysql -uroot -e 'SELECT name FROM mysql.proc WHERE db = \"#{node['bcpc']['dbname']['zabbix']}\" AND type = \"procedure\" AND name LIKE \"partition%\"' | grep -q partition >/dev/null" }
    end

    # Creates wrapper stored procedure to execute partitioning, then
    # reconfigures Zabbix housekeeping to match partitioning setup
    ruby_block "zabbix-mysql-partition-maintenance-all" do
        block do
            %x[ export MYSQL_PWD=#{get_config('mysql-zabbix-password')};
                mysql -u#{get_config('mysql-zabbix-user')} #{node['bcpc']['dbname']['zabbix']} < /tmp/zabbix-mysql-partition-maintenance-all.sql
            ]
        end
    end

    template "/usr/local/bin/zabbix-mysql-partition-maintenance-all" do
        source "zabbix-mysql-partition-maintenance-all-cron.erb"
        owner "zabbix"
        group "root"
        mode "0750"
    end

    # Partitions need to be pre-extended, so running this as a daily crontab
    cron 'partition-maintenance-all' do
        minute '7'
        hour '0'
        user 'zabbix'
        command "/usr/local/bin/zabbix-mysql-partition-maintenance-all >/dev/null 2>&1"
    end

end
