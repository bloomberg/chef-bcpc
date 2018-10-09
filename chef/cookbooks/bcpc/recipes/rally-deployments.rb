#
# Cookbook Name:: bcpc-extra
# Recipe:: rally-deployments
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
# Note: The rally.rb recipe must have already been executed before running this one.
# IMPORTANT: The head nodes MUST have already been installed and the keystone endpoints working. Rally verifies.

KEYSTONE_API_VERSION = "v3"
rally_user = node['bcpc-extra']['rally']['user']
rally_home_dir = node['etc']['passwd'][rally_user]['dir']
rally_install_dir = "#{rally_home_dir}/rally"
rally_venv_dir = "#{rally_install_dir}/venv"
rally_deployment = "v2.0"

directory "/tmp/rally" do
  owner rally_user
  group rally_user
  mode 00755
  action :create
end
# Have the image file ready for image based tests
cookbook_file "/tmp/rally/cirros-0.3.4-x86_64-disk.img" do
    source "cirros-0.3.4-x86_64-disk.img"
    cookbook 'bcpc-binary-files'
    owner rally_user
    mode 00444
end

infile = File.join(Chef::Config[:file_cache_path], "rally-existing-#{KEYSTONE_API_VERSION}.json")
template "#{infile}" do
    user rally_user
    source "rally/rally.existing.json.erb"
    owner rally_user
    group rally_user
    mode 0600
    variables(
      api_version: KEYSTONE_API_VERSION,
      region_name:  node.chef_environment,
      username: get_config('keystone-admin-user'),
      password: get_config('keystone-admin-password'),
      project_name: get_config('keystone-admin-project-name'),
      domain_name: get_config('keystone-admin-user-domain')
    )
end

# Also required is a hostsfile (or DNS) entry for API endpoint hostname
hostsfile_entry "#{node['bcpc']['management']['vip']}" do
  hostname "openstack.#{node['bcpc']['cluster_domain']}"
  action :create_if_missing
end

infile = File.join(Chef::Config[:file_cache_path], "rally-existing-#{KEYSTONE_API_VERSION}.json")
bash "rally-deployment-create-#{KEYSTONE_API_VERSION}" do
    user rally_user
    code <<-EOH
        # Another approach is to use --fromenv...
        source #{rally_venv_dir}/bin/activate
        rally deployment destroy #{KEYSTONE_API_VERSION}
        rally deployment create --filename="#{infile}" --name=#{KEYSTONE_API_VERSION}
    EOH
end
