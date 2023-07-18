# Cookbook:: bcpc
# Recipe:: apparmor
#
# Copyright:: 2023 Bloomberg Finance L.P.
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

# The apparmor capabilities parsing bug only applies to Focal
if platform?('ubuntu') && node['platform_version'] == '20.04'
  libapparmor1_package = node['bcpc']['apparmor']['libapparmor1']['file']
  libapparmor1_save_path = "#{Chef::Config[:file_cache_path]}/#{libapparmor1_package}"
  libapparmor1_file_url = node['bcpc']['apparmor']['libapparmor1']['source']
  libapparmor1_checksum = node['bcpc']['apparmor']['libapparmor1']['checksum']

  apparmor_package = node['bcpc']['apparmor']['apparmor']['file']
  apparmor_save_path = "#{Chef::Config[:file_cache_path]}/#{apparmor_package}"
  apparmor_file_url = node['bcpc']['apparmor']['apparmor']['source']
  apparmor_checksum = node['bcpc']['apparmor']['apparmor']['checksum']

  remote_file libapparmor1_save_path do
    source libapparmor1_file_url
    checksum libapparmor1_checksum
    notifies :run, 'execute[install libapparmor1]', :immediately
  end

  remote_file apparmor_save_path do
    source apparmor_file_url
    checksum apparmor_checksum
    notifies :run, 'execute[install apparmor]', :immediately
  end

  execute 'install libapparmor1' do
    action :nothing
    command "dpkg -i #{Chef::Config[:file_cache_path]}/#{libapparmor1_package}"
  end

  execute 'install apparmor' do
    action :nothing
    command "dpkg -i #{Chef::Config[:file_cache_path]}/#{apparmor_package}"
    notifies :restart, 'service[apparmor]', :immediately
  end
end

service 'apparmor'
