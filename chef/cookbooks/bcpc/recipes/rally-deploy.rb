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

return unless node['bcpc']['rally']['enabled']

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
service = node['bcpc']['catalog']['identity']
auth_url = generate_service_catalog_uri(service, 'public')
home_dir = node['bcpc']['rally']['home_dir']

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

template "#{home_dir}/rally-openstack.yml" do
  owner 'rally'
  group 'rally'
  source 'rally/rally-existing.yml.erb'
  mode '0600'
  variables(
    auth_url: auth_url,
    region_name: region,
    domain_name: 'default',
    username: node['bcpc']['openstack']['admin']['username'],
    password: config['openstack']['admin']['password'],
    project_name: node['bcpc']['openstack']['admin']['project']
  )
end

execute 'create openstack rally deployment' do
  environment env
  user 'rally'
  command <<-EOH
    rally env create \
      --spec "#{home_dir}/rally-openstack.yml" \
      --name openstack
  EOH
  not_if 'rally env show openstack'
end

execute 'create tempest verifier' do
  # after this section, tempest can be run as follows
  #  $ sudo -u rally -i
  #  $ rally verify start tempest
  #  $ rally verify list
  #  $ rally verify report --type html-static --to rally.html --uuid <uuid>
  environment env
  user 'rally'
  command <<-EOH
    rally verify create-verifier \
      --type tempest \
      --name tempest
  EOH
  not_if 'rally verify show-verifier tempest'
end
