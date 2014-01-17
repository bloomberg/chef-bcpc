#
# Cookbook Name:: bcpc
# Recipe:: zabbix-head
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

include_recipe "bcpc::mysql"
include_recipe "bcpc::horizon"
include_recipe "bcpc::apache2"

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

remote_file "/tmp/zabbix-server.tar.gz" do
    source "#{get_binary_server_url}/zabbix-server.tar.gz"
    owner "root"
    mode 00444
    not_if { File.exists?("/usr/local/sbin/zabbix_server") }
end

bash "install-zabbix-server" do
    code "tar zxf /tmp/zabbix-server.tar.gz -C /usr/local/ && rm /tmp/zabbix-server.tar.gz"
    not_if { File.exists?("/usr/local/sbin/zabbix_server") }
end

user node[:bcpc][:zabbix][:user] do
    shell "/bin/false"
    home "/var/log"
    gid node[:bcpc][:zabbix][:group]
    system true
end

directory "/var/log/zabbix" do
    user node[:bcpc][:zabbix][:user]
    group node[:bcpc][:zabbix][:group]
    mode 00755
end

template "/etc/init/zabbix-server.conf" do
    source "upstart-zabbix-server.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[zabbix-server]", :delayed
end

template "/usr/local/etc/zabbix_server.conf" do
    source "zabbix_server.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-server]", :delayed
end

ruby_block "zabbix-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['zabbix_dbname']}\"'|grep \"#{node['bcpc']['zabbix_dbname']}\"" then
            puts %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['zabbix_dbname']} CHARACTER SET UTF8;"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['zabbix_dbname']}.* TO '#{get_config('mysql-zabbix-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-zabbix-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['zabbix_dbname']}.* TO '#{get_config('mysql-zabbix-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-zabbix-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['zabbix_dbname']} < /usr/local/share/zabbix/schema.sql
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['zabbix_dbname']} < /usr/local/share/zabbix/images.sql
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['zabbix_dbname']} < /usr/local/share/zabbix/data.sql
                HASH=`echo -n "#{get_config('zabbix-admin-password')}" | md5sum | awk '{print $1}'`
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['zabbix_dbname']} -e "UPDATE users SET passwd=\\"$HASH\\" WHERE alias=\\"#{get_config('zabbix-admin-user')}\\";"
                HASH=`echo -n "#{get_config('zabbix-guest-password')}" | md5sum | awk '{print $1}'`
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['zabbix_dbname']} -e "UPDATE users SET passwd=\\"$HASH\\" WHERE alias=\\"#{get_config('zabbix-guest-user')}\\";"
            ]
        end
    end
end

service "zabbix-server" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
end

%w{traceroute php5-mysql php5-gd}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

file "/etc/php5/apache2/conf.d/zabbix.ini" do
    user "root"
    group "root"
    mode 00644
    content <<-EOH
        post_max_size = 16M
        max_execution_time = 300
        max_input_time = 300
        date.timezone = America/New_York
    EOH
    notifies :restart, "service[apache2]", :delayed
end

template "/usr/local/share/zabbix/php/conf/zabbix.conf.php" do
    source "zabbix.conf.php.erb"
    user node[:bcpc][:zabbix][:user]
    group "www-data"
    mode 00640
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/apache2/sites-available/zabbix-web" do
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
    not_if "test -r /etc/apache2/sites-enabled/zabbix-web"
    notifies :restart, "service[apache2]", :delayed
end

include_recipe "bcpc::zabbix-work"

template "/usr/local/etc/zabbix_agentd.conf.d/zabbix-openstack.conf" do
    source "zabbix_openstack.conf.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00600
    notifies :restart, "service[zabbix-agent]", :immediately
end


directory "/usr/local/bin/checks" do
  action :create
  owner  node[:bcpc][:zabbix][:user]
  group "root"
  mode 00775
end 

directory "/usr/local/etc/checks" do
  action  :create
  owner  node[:bcpc][:zabbix][:user]
  group "root"
  mode 00775
end 

template  "/usr/local/etc/checks/default.yml" do
  source "checks/default.yml.erb"
  owner node[:bcpc][:zabbix][:user]
  group "root"
  mode 00640
end

cookbook_file "/usr/local/bin/check" do
  source "checks/check"
  owner "root"
  mode "00755"
end

%w{ nova rgw }.each do |cc| 
  template  "/usr/local/etc/checks/#{cc}.yml" do
    source "checks/#{cc}.yml.erb"
    owner node[:bcpc][:zabbix][:user]
    group "root"
    mode 00640
  end
  
  cookbook_file "/usr/local/bin/checks/#{cc}" do
    source "checks/#{cc}"
    owner "root"
    mode "00755"
  end

  cron "check-#{cc}" do
    home "/var/lib/zabbix"
    user "zabbix"
    minute "0"
    path "/usr/local/bin:/usr/bin:/bin"
    command "zabbix_sender -c /usr/local/etc/zabbix_agentd.conf --key 'check.#{cc}' --value `check -f timeonly #{cc}`"
  end
end

package "python-requests-aws" do
end

template "/usr/local/bin/zabbix_bucket_stats" do
  source "zabbix_bucket_stats.erb"
  owner "root"
  group "root"
  mode "00755"
end

