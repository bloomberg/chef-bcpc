#
# Cookbook Name:: bcpc-extra
# Recipe:: postfix
#
# Copyright 2017, Bloomberg Finance L.P.
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

return unless node['bcpc-extra']['postfix']['enabled']

package 'exim4' do
  action :remove
end

package 'bsd-mailx' do
  action :install
end

package 'postfix' do
  action :install
end

template 'postfix-main.cf' do
  path '/etc/postfix/main.cf'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  notifies :restart, 'service[postfix]'
end

service 'postfix' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

ruby_block 'add_root_mail_alias' do
  block do
    mail_alias = 'root: ' + node['bcpc-extra']['postfix']['root_mail_alias']
    file = Chef::Util::FileEdit.new('/etc/aliases')
    file.search_file_replace_line(/^root:/, mail_alias)
    file.insert_line_if_no_match(/^root:/, mail_alias)
    file.write_file
  end
  notifies :run, 'execute[run-newaliases]', :immediately
end

execute 'run-newaliases' do
  command '/usr/bin/newaliases'
  action :nothing
  notifies :restart, 'service[postfix]'
end
