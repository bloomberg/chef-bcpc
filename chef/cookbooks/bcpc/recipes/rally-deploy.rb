# Cookbook:: bcpc
# Recipe:: rally-deploy
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

# Note: The rally.rb recipe must have already been executed before running this one.
# IMPORTANT: The head nodes MUST have already been installed and the keystone endpoints working. Rally verifies.

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
rally_user = node['bcpc']['rally']['user']
home_dir = node['bcpc']['rally']['home_dir']
venv_dir = node['bcpc']['rally']['venv_dir']
keystone_api_version = node['bcpc']['rally']['keystone']['version']
file_cache = Chef::Config[:file_cache_path]
deployment_config = "rally-existing-#{keystone_api_version}.json"
deployment_config = File.join(file_cache, deployment_config)
identity = node['bcpc']['catalog']['identity']
auth_url = generate_service_catalog_uri(identity, 'public')
env = { 'HOME' => home_dir }

template deployment_config do
  user rally_user
  source 'rally/rally.existing.json.erb'
  mode 0600
  variables(
    auth_url: auth_url,
    region_name: region,
    domain_name: 'default',
    api_version: keystone_api_version,
    username: node['bcpc']['openstack']['admin']['username'],
    password: config['openstack']['admin']['password'],
    project_name: node['bcpc']['openstack']['admin']['project']
  )
end

bash "rally deployment create: #{keystone_api_version}" do
  environment env
  user rally_user
  code <<-EOH
    # Another approach is to use --fromenv...
    source #{venv_dir}/bin/activate

    rally deployment destroy #{keystone_api_version}
    rally deployment create \
      --filename="#{deployment_config}" \
      --name=#{keystone_api_version}
  EOH
end
