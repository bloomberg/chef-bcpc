# Cookbook:: bcpc
# Recipe:: rally
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

return unless node['bcpc']['rally']['enabled']

package 'virtualenv'

rally_user = node['bcpc']['rally']['user']
rally_group = node['bcpc']['rally']['group']
home_dir = node['bcpc']['rally']['home_dir']
install_dir = node['bcpc']['rally']['install_dir']
venv_dir = node['bcpc']['rally']['venv_dir']
conf_dir = node['bcpc']['rally']['conf_dir']
database_dir = node['bcpc']['rally']['database_dir']
version = node['bcpc']['rally']['version']

# pip uses the HOME env to figure out the users home directory. chef
# doesn't change this variable when running as another user so pip install
# breaks because of permission errors
env = { 'HOME' => home_dir }

if node['bcpc']['proxy']['enabled']
  node['bcpc']['proxy']['proxies'].each do |key, value|
    env["#{key}_proxy"] = value
  end
end

env['CURL_CA_BUNDLE'] = '' unless node['bcpc']['rally']['ssl_verify']

group rally_group

user rally_user do
  gid rally_group
  home home_dir
  manage_home true
  shell '/bin/bash'
  comment 'Openstack Rally Runner'
end

sudo rally_user do
  user rally_user
  nopasswd true
  commands ['/usr/bin/chef-client']
end

directory install_dir do
  owner rally_user
  group rally_group
end

execute 'create virtual env for rally' do
  environment env
  user rally_user
  command <<-EOH
    virtualenv #{venv_dir}
  EOH
end

bash 'install rally' do
  environment env
  user rally_user
  code <<-EOH
    #{venv_dir}/bin/pip install pbr
    #{venv_dir}/bin/pip install rally-openstack==#{version}
  EOH
end

directory conf_dir do
  owner rally_user
  group rally_group
end

template "#{conf_dir}/rally.conf" do
  source 'rally/rally.conf.erb'
  owner rally_user
  group rally_group
  variables(
    db_location: database_dir
  )
end

directory database_dir do
  owner rally_user
  group rally_group
end

bash 'setup rally database' do
  user rally_user
  code <<-EOH
    source #{venv_dir}/bin/activate
    rally-manage db recreate
  EOH
end
