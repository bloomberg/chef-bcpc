# Cookbook:: bcpc
# Recipe:: postfix
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

return unless node['bcpc']['postfix']['enabled']

package 'exim4' do
  action :remove
  options '--no-install-recommends'
end

package %w(
  bsd-mailx
  postfix
) do
  options '--no-install-recommends'
end

service 'postfix'

template '/etc/postfix/main.cf' do
  source 'postfix/main.cf.erb'
  notifies :restart, 'service[postfix]', :immediately
end

ruby_block 'add_root_mail_alias' do
  block do
    mail_alias = 'root: ' + node['bcpc']['postfix']['root_mail_alias']
    file = Chef::Util::FileEdit.new('/etc/aliases')
    file.search_file_replace_line(/^root:/, mail_alias)
    file.insert_line_if_no_match(/^root:/, mail_alias)
    file.write_file
  end
  notifies :run, 'execute[run-newaliases]', :immediately
end

execute 'run-newaliases' do
  action :nothing
  command '/usr/bin/newaliases'
  notifies :restart, 'service[postfix]', :immediately
end
