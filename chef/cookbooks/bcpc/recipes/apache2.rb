#
# Cookbook:: bcpc
# Recipe:: apache2
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

package %w(
  apache2
  apache2-utils
  libapache2-mod-fcgid
  libapache2-mod-wsgi
) do
  options '--no-install-recommends'
end

service 'apache2'

# log rotation configuration
template '/etc/cron.d/logrotate-apache2' do
  source 'apache2/cron-logrotate.erb'
  variables(
    headnodes: headnodes(all: true)
  )
end

remote_file '/etc/apache2/logrotate.conf' do
  only_if { ::File.exist?('/etc/logrotate.d/apache2') }
  source 'file:///etc/logrotate.d/apache2'
  owner 'root'
  group 'root'
  mode 0644
  action :create
end

file '/etc/logrotate.d/apache2' do
  action :delete
  backup false
end

# server configuration
template '/etc/apache2/conf-available/keepalive.conf' do
  source 'apache2/keepalive.conf.erb'
  notifies :restart, 'service[apache2]', :delayed
end

%w(
  keepalive
).each do |conf|
  execute "enable #{conf} apache2 configuration" do
    command "a2enconf #{conf}"
    not_if "a2query -c #{conf}"
    notifies :restart, 'service[apache2]', :delayed
  end
end

# module selection
extra_mods = ['status']
extra_disabled_mods = extra_mods.map { |x| x unless node['bcpc']['apache2'][x]['enabled'] }.compact
extra_enabled_mods = extra_mods.map { |x| x if node['bcpc']['apache2'][x]['enabled'] }.compact

%w(
  mpm_prefork
  mpm_worker
).concat(extra_disabled_mods).each do |mod|
  execute "disable #{mod} apache2 module" do
    command "a2dismod #{mod}"
    only_if "a2query -m #{mod}"
    notifies :restart, 'service[apache2]', :delayed
  end
end

%w(
  ssl
  wsgi
  proxy_http
  rewrite
  cache
  cache_disk
  mpm_event
).concat(extra_enabled_mods).each do |mod|
  execute "enable #{mod} apache2 module" do
    command "a2enmod #{mod}"
    not_if "a2query -m #{mod}"
    notifies :restart, 'service[apache2]', :delayed
  end
end

# mpm_event tuning
template '/etc/apache2/mods-available/mpm_event.conf' do
  source 'apache2/mpm_event.conf.erb'
  notifies :restart, 'service[apache2]', :delayed
end

# apache status module
if node['bcpc']['apache2']['status']['enabled']
  # create htpasswd file for apache status
  apache_status_username = config['apache']['status']['username']
  apache_status_password = config['apache']['status']['password']
  execute 'set password for apache_status user' do
    command "htpasswd -cb /etc/apache2/server_status_htpasswd #{apache_status_username} #{apache_status_password}"
    sensitive true
    notifies :restart, 'service[apache2]', :delayed
    not_if "htpasswd -bv /etc/apache2/server_status_htpasswd #{apache_status_username} #{apache_status_password}"
  end

  # secure the htpasswd file for apache_status
  file '/etc/apache2/server_status_htpasswd' do
    mode '0640'
    owner 'root'
    group 'www-data'
    notifies :restart, 'service[apache2]', :delayed
  end

  # status module tuning
  template '/etc/apache2/mods-available/status.conf' do
    source 'apache2/status.conf.erb'
    variables(
      status_user: apache_status_username,
      htpasswd_file: '/etc/apache2/server_status_htpasswd'
    )
    notifies :restart, 'service[apache2]', :delayed
  end
end

# remote default ssl site conf
file '/etc/apache2/sites-available/default-ssl.conf' do
  action :delete
end

template '/etc/apache2/sites-available/000-default.conf' do
  source 'apache2/default.conf.erb'
  notifies :restart, 'service[apache2]', :delayed
end

template '/var/www/index.html' do
  source 'apache2/index.html.erb'

  version = run_context.cookbook_collection[cookbook_name].metadata.version

  intermediate = config['ssl']['intermediate']
  intermediate = Base64.decode64(intermediate) unless intermediate.nil?

  variables(
    cookbook_version: version,
    vip: node['bcpc']['cloud']['vip'],
    ssl_crt: Base64.decode64(config['ssl']['crt']),
    ssl_intermediate: intermediate
  )
end

template '/etc/apache2/ports.conf' do
  source 'apache2/ports.conf.erb'
  notifies :restart, 'service[apache2]', :immediately
end
