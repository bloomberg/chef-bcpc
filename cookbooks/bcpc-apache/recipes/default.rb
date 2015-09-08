#
# Cookbook Name:: bcpc-apache
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

%w{apache2 libapache2-mod-fastcgi libapache2-mod-wsgi libapache2-mod-python libapache2-mod-php5}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

%w{ssl wsgi python php5 proxy_http rewrite cache cache_disk}.each do |mod|
    bash "apache-enable-#{mod}" do
        user "root"
        code "a2enmod #{mod}"
        not_if "test -r /etc/apache2/mods-enabled/#{mod}.load"
        notifies :restart, "service[apache2]", :delayed
    end
end

template "/etc/apache2/sites-enabled/000-default" do
    source "apache-000-default.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

bash "set-apache-bind-address" do
    code <<-EOH
        sed -i "s/\\\(^[\\\t ]*Listen[\\\t ]*\\\)80[\\\t ]*$/\\\\1#{node['bcpc']['management']['ip']}:80/g" /etc/apache2/ports.conf
        sed -i "s/\\\(^[\\\t ]*Listen[\\\t ]*\\\)443[\\\t ]*$/\\\\1#{node['bcpc']['management']['ip']}:443/g" /etc/apache2/ports.conf
    EOH
    not_if "grep #{node['bcpc']['management']['ip']} /etc/apache2/ports.conf"
    notifies :restart, "service[apache2]", :immediately
end

service "apache2" do
    action [:enable, :start]
    supports :status => true, :reload => true
    provider Chef::Provider::Service::Init::Debian
end

template "/var/www/html/index.html" do
    source "index.html.erb"
    owner "root"
    group "root"
    mode 00644
    variables ({ :cookbook_version => run_context.cookbook_collection['bcpc-foundation'].metadata.version })
end

directory "/var/www/cgi-bin" do
  action :create
  owner  "root"
  group  "root"
  mode   00755
end
