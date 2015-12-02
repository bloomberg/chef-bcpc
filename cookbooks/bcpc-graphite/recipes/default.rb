#
# Cookbook Name:: bcpc-graphite
# Recipe:: default
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

if node['bcpc']['enabled']['metrics']
    include_recipe "bcpc-apache"
    include_recipe 'bcpc-mysql::monitornode'

    ruby_block "initialize-graphite-config" do
        block do
            make_config('mysql-graphite-user', "graphite")
            make_config('mysql-graphite-password', secure_password)
            make_config('graphite-secret-key', secure_password)
        end
    end

    %w{python-whisper_0.9.13_all.deb python-carbon_0.9.13_all.deb python-graphite-web_0.9.13_all.deb}.each do |pkg|
        cookbook_file "/tmp/#{pkg}" do
            source pkg
            cookbook 'bcpc-binary-files'
            owner "root"
            mode 00444
        end

        package pkg do
            provider Chef::Provider::Package::Dpkg
            source "/tmp/#{pkg}"
            action :install
        end
    end

    %w{python-pip python-cairo python-django python-django-tagging python-ldap python-twisted python-memcache memcached python-mysqldb python-tz}.each do |pkg|
        package pkg do
            action :upgrade
        end
    end

    #  _   _  ____ _  __   __  ____   _  _____ ____ _   _
    # | | | |/ ___| | \ \ / / |  _ \ / \|_   _/ ___| | | |
    # | | | | |  _| |  \ V /  | |_) / _ \ | || |   | |_| |
    # | |_| | |_| | |___| |   |  __/ ___ \| || |___|  _  |
    #  \___/ \____|_____|_|   |_| /_/   \_\_| \____|_| |_|
    # carbon-relay sometimes remain stuck even when destinations have
    # (i.e, carbon-cache) recovered from lag/unresponsiveness. This patch
    # applies Graphite Carbon PR #400 which fixes a race condition in carbon
    # client queue signalling.
    cookbook_file "/tmp/graphite-carbon-client.patch" do
        source "graphite-carbon-client.patch"
        owner "root"
        mode 00644
    end

    bash "patch-for-graphite-carbon-client" do
        user "root"
        code <<-EOH
           cd /opt/graphite
           patch -p1 < /tmp/graphite-carbon-client.patch
           rv=$?
           if [ $rv -ne 0 ]; then
             echo "Error applying patch ($rv) - aborting!"
             exit $rv
           fi
           cp /tmp/graphite-carbon-client.patch .
        EOH
        not_if "grep -q 'THIS FILE PATCHED BY BCPC' /opt/graphite/lib/carbon/client.py"
        notifies :restart, "service[carbon-relay]", :delayed
    end

    template "/opt/graphite/conf/carbon.conf" do
        source "carbon.conf.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
          lazy {
            {
              :servers    => get_nodes_with_recipe('bcpc-graphite'),
              :min_quorum => get_nodes_with_recipe('bcpc-graphite').length/2 + 1
            }
          }
        )
        notifies :restart, "service[carbon-cache]", :delayed
        notifies :restart, "service[carbon-relay]", :delayed
    end

    template "/opt/graphite/conf/storage-schemas.conf" do
        source "carbon-storage-schemas.conf.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :restart, "service[carbon-cache]", :delayed
    end

    template "/opt/graphite/conf/storage-aggregation.conf" do
        source "carbon-storage-aggregation.conf.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :restart, "service[carbon-cache]", :delayed
    end

    template "/opt/graphite/conf/relay-rules.conf" do
        source "carbon-relay-rules.conf.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
          lazy {
            {:servers => get_nodes_with_recipe('bcpc-graphite')}
          }
        )
        notifies :restart, "service[carbon-relay]", :delayed
    end

    template "/etc/apache2/sites-available/graphite-web.conf" do
        source "apache-graphite-web.conf.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :restart, "service[apache2]", :delayed
    end

    bash "apache-enable-graphite-web" do
        user "root"
        code "a2ensite graphite-web"
        not_if "test -r /etc/apache2/sites-enabled/graphite-web"
        notifies :restart, "service[apache2]", :delayed
    end

    template "/opt/graphite/conf/graphite.wsgi" do
        source "graphite.wsgi.erb"
        owner "root"
        group "root"
        mode 00755
    end

    template "/opt/graphite/webapp/graphite/local_settings.py" do
        source "graphite.local_settings.py.erb"
        owner "root"
        group "root"
        mode 00644
        variables(
          lazy {
            {:servers => get_nodes_with_recipe('bcpc-graphite')}
          }
        )
        notifies :restart, "service[apache2]", :delayed
    end

    bash "remove-app-settings-secret-key" do
        user "root"
        code "sed --in-place '/^SECRET_KEY /d' /opt/graphite/webapp/graphite/app_settings.py"
        only_if "grep -e '^SECRET_KEY ' /opt/graphite/webapp/graphite/app_settings.py"
    end

    execute "graphite-storage-ownership" do
        user "root"
        command "chown -R www-data:www-data /opt/graphite/storage"
        not_if "ls -ald /opt/graphite/storage | awk '{print $3}' | grep www-data"
    end

    ruby_block "graphite-database-creation" do
      block do
        cmd = Mixlib::ShellOut.new(
          "export MYSQL_PWD=#{get_config('mysql-monitoring-root-password')}; \
            mysql -uroot -e \"CREATE DATABASE #{node['bcpc']['dbname']['graphite']};\"
            mysql -uroot -e \"GRANT ALL ON #{node['bcpc']['dbname']['graphite']}.* TO \
            '#{get_config('mysql-graphite-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-graphite-password')}';\"
            mysql -uroot -e \"GRANT ALL ON #{node['bcpc']['dbname']['graphite']}.* TO \
            '#{get_config('mysql-graphite-user')}'@'localhost' IDENTIFIED BY \
            '#{get_config('mysql-graphite-password')}';\"
            mysql -uroot -e \"FLUSH PRIVILEGES;\""
        ).run_command
        cmd.error!
        self.notifies :run, "bash[graphite-database-sync]", :immediately
        self.resolve_notification_references
      end
      only_if {
        cmd = Mixlib::ShellOut.new("MYSQL_PWD=#{get_config('mysql-monitoring-root-password')} mysql -uroot -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['dbname']['graphite']}\"'").run_command
        cmd.stdout.empty? # if empty, Graphite schema was not found
      }
    end

    bash "graphite-database-sync" do
        action :nothing
        user "root"
        code <<-EOH
            python /opt/graphite/webapp/graphite/manage.py syncdb --noinput
            python /opt/graphite/webapp/graphite/manage.py createsuperuser --username=admin --email=#{node['bcpc']['admin_email']} --noinput
        EOH
        notifies :restart, "service[apache2]", :immediately
    end

    %w{cache relay}.each do |pkg|
        template "/etc/init.d/carbon-#{pkg}" do
            source "init.d-carbon.erb"
            owner "root"
            group "root"
            mode 00755
            notifies :restart, "service[carbon-#{pkg}]", :delayed
            variables(:daemon => pkg)
        end
        service "carbon-#{pkg}" do
            action [:enable, :start]
        end
    end

end
