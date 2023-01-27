# Cookbook:: bcpc
# Recipe:: rally
#
# Copyright:: 2022 Bloomberg Finance L.P.
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

conf_dir = node['bcpc']['rally']['conf_dir']
home_dir = node['bcpc']['rally']['home_dir']
venv_dir = node['bcpc']['rally']['venv_dir']
rally_version = node['bcpc']['rally']['rally']['version']
rally_openstack_version = node['bcpc']['rally']['rally_openstack']['version']
database_dir = node['bcpc']['rally']['database_dir']

# pip uses the HOME env to figure out the users home directory. chef
# doesn't change this variable when running as another user so pip install
# breaks because of permission errors
env = {
  'HOME' => home_dir,
  'PATH' => '/usr/local/lib/rally/bin::/usr/sbin:/usr/bin:/sbin:/bin',
}

if node['bcpc']['local_proxy']['enabled']
  local_proxy_config = node['bcpc']['local_proxy']['config']
  local_proxy_listen = local_proxy_config['listen']
  local_proxy_port = local_proxy_config['port']
  local_proxy_url = "http://#{local_proxy_listen}:#{local_proxy_port}"
  env['http_proxy'] = local_proxy_url
  env['https_proxy'] = local_proxy_url
end

env['CURL_CA_BUNDLE'] = '' unless node['bcpc']['rally']['ssl_verify']

package %w(
  virtualenv
  python3-dev
)

group 'rally'

user 'rally' do
  gid 'rally'
  home home_dir
  manage_home true
  shell '/bin/bash'
  comment 'OpenStack Rally Runner'
end

directory home_dir do
  owner 'rally'
  group 'rally'
  mode '0700'
end

file "#{home_dir}/.bash_profile" do
  owner 'rally'
  group 'rally'
  mode '0600'
  content 'export PATH=/usr/local/lib/rally/bin:/usr/sbin:/usr/bin:/sbin:/bin'
end

directory venv_dir do
  owner 'rally'
  group 'rally'
end

execute 'install rally in virtualenv' do
  environment env
  retries 3
  user 'rally'
  # Installation notes:
  # - 'pip' is pinned to avoid issues when installing `cryptography>3.4` as
  #     part of `pycryptodome` etc.
  # - 'decorator' is pinned due to https://bugs.launchpad.net/rally/+bug/1922707
  # - 'jinja2' is pinned due to a change in how 3.0.0+ handles variables set in
  #     templates containing macros. This change breaks rally tasks used
  #     internally by Bloomberg, which likely need to be fixed.
  command <<-EOH
    virtualenv --no-download #{venv_dir} -p /usr/bin/python3
    . #{venv_dir}/bin/activate
    pip install 'pip>=19.1.1'
    pip install 'decorator<=4.4.2'
    pip install 'jinja2<3.0.0'
    pip install 'markupsafe==2.0.1'
    pip install 'SQLAlchemy<2.0.0'
    pip install rally-openstack==#{rally_openstack_version} rally==#{rally_version}
  EOH
  not_if "rally --version | grep rally-openstack | grep #{rally_openstack_version}"
end

directory conf_dir do
  owner 'rally'
  group 'rally'
end

template "#{conf_dir}/rally.conf" do
  source 'rally/rally.conf.erb'
  owner 'rally'
  group 'rally'
  variables(
    database_dir: database_dir
  )
end

directory database_dir do
  owner 'rally'
  group 'rally'
end

execute 'setup rally database' do
  environment env
  user 'rally'
  command <<-EOH
    rally db ensure
    rally db upgrade
  EOH
end
