# Cookbook Name:: bcpc
# Recipe:: rally
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

rally_user = node['bcpc']['rally']['user']
rally_home_dir = node['etc']['passwd'][rally_user]['dir']
rally_install_dir = "#{rally_home_dir}/rally"
rally_venv_dir = "#{rally_install_dir}/venv"
rally_conf_dir = "#{rally_venv_dir}/etc/rally"
rally_database_dir = "#{rally_venv_dir}/database"
rally_version = node['bcpc']['rally']['version']

%w{
     wget
     build-essential
     libssl-dev
     libffi-dev
     python-dev
     libpq-dev
     libxml2-dev
     libxslt1-dev
}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

bash 'create virtual env for rally' do
  code <<-EOH
    mkdir "#{rally_install_dir}"
    pip install --user --upgrade virtualenv
    #{rally_home_dir}/.local/bin/virtualenv "#{rally_venv_dir}"
  EOH
  user rally_user
end

bash 'install-rally' do
  code <<-EOH
    #{rally_venv_dir}/bin/pip install pbr cffi
    #{rally_venv_dir}/bin/pip install rally==#{rally_version}
  EOH
  user rally_user
end

directory "#{rally_conf_dir}" do
    user rally_user
    owner rally_user
    group rally_user
    mode "0755"
    action :create
end

template "#{rally_conf_dir}/rally.conf" do
    source "rally.conf.erb"
    user rally_user
    owner rally_user
    group rally_user
    mode 0664
    variables(
      db_location: "#{rally_database_dir}"
    )
end

directory "#{rally_database_dir}" do
    user rally_user
    owner rally_user
    group rally_user
    mode "0755"
    action :create
end

bash "setup rally database" do
  code <<-EOH
    source #{rally_venv_dir}/bin/activate
    rally-manage db recreate
  EOH
  user rally_user
end
