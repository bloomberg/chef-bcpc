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

%w(apache2 libapache2-mod-fastcgi libapache2-mod-wsgi apache2-utils).each do |pkg|
  package pkg do
    action :install
  end
end

template '/etc/apache2/sites-available/000-default.conf' do
  source 'apache2/default.conf.erb'
  notifies :restart, 'service[apache2]', :delayed
end

template '/var/www/html/index.html' do
  source 'apache2/index.html.erb'

  version = run_context.cookbook_collection[cookbook_name].metadata.version

  variables(
    config: config,
    vip: get_address(node['bcpc']['cloud']['vip']['ip']),
    cookbook_version: version
  )
end

template '/etc/apache2/ports.conf' do
  source 'apache2/ports.conf.erb'
  notifies :restart, 'service[apache2]', :immediately
end
