#
# Cookbook Name:: bcpc
# Recipe:: apache2
#
# Copyright 2016, Bloomberg Finance L.P.
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

%w{apache2 libapache2-mod-fastcgi libapache2-mod-wsgi apache2-utils}.each do |pkg|
    package pkg do
        action :install
    end
end

%w[
  python
].each do |mod|
  execute "disable #{mod} apache2 module" do
    command "a2dismod #{mod}"
    only_if "a2query -m #{mod}"
    notifies :restart, "service[apache2]", :delayed
  end
end

# Remove PHP packages from non-monitoring nodes
package 'php5-common' do
  action :purge
  not_if do
    search_nodes('role', 'BCPC-Alerting').include?(node) ||
    search_nodes('role', 'BCPC-Logging').include?(node) ||
    search_nodes('role', 'BCPC-Metrics').include?(node)
  end
end

template "/etc/apache2/sites-enabled/000-default" do
  source "apache-000-default.erb"
  notifies :restart, "service[apache2]", :delayed
end

template "/var/www/html/index.html" do
  source "index.html.erb"

  variables ({
    :cookbook_version => run_context.cookbook_collection[cookbook_name].metadata.version
  })
end

directory "/var/www/cgi-bin" do
  mode 00755
end

template "/etc/apache2/ports.conf" do
  source "apache2/ports.conf.erb"
  notifies :restart, "service[apache2]", :immediately
end
