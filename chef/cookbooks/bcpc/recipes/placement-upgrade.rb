# Cookbook:: bcpc
# Recipe:: placement-upgrade
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

mysqladmin = mysqladmin()

# used for database creation and access
#
database = {
  'host' => node['bcpc']['mysql']['host'],
  'port' => node['bcpc']['mysql']['port'],
  'dbname' => node['bcpc']['placement']['db']['dbname'],
  'username' => config['placement']['creds']['db']['username'],
  'password' => config['placement']['creds']['db']['password'],
}

# placement openstack access
#
openstack = {
  'role' => node['bcpc']['keystone']['roles']['admin'],
  'project' => node['bcpc']['keystone']['service_project']['name'],
  'domain' => node['bcpc']['keystone']['service_project']['domain'],
  'username' => config['placement']['creds']['os']['username'],
  'password' => config['placement']['creds']['os']['password'],
}

# erb files to render out
#
template '/tmp/placement-create-db.sql' do
  source 'placement/placement-create-db.sql.erb'

  variables(
    db: database
  )
end

template '/etc/placement/placement.conf' do
  source 'placement/placement.conf.erb'
  mode '0640'
  owner 'root'
  group 'placement'

  variables(
    db: database,
    os: openstack,
    config: config,
    is_headnode: headnode?,
    headnodes: headnodes(all: true),
    rmqnodes: rmqnodes(all: true),
    vip: node['bcpc']['cloud']['vip']
  )
end

# files to facilitate cutover to placement
#
cookbook_file '/tmp/migrate-db.sh' do
  source 'placement/migrate-db.sh'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/tmp/migrate-db.rc' do
  source 'placement/migrate-db.rc.erb'
  mode '0640'
  owner 'root'
  group 'root'

  variables(
    config: config,
  )
end

# TODO: @tstachecki: differs from /etc/placement/placement.conf?
placement_processes = if !node['bcpc']['placement']['workers'].nil?
                        node['bcpc']['placement']['workers']
                      else
                        node['bcpc']['openstack']['services']['workers']
                      end

template '/etc/apache2/sites-available/placement-api.conf' do
  source 'placement/placement-api.conf.erb'
  mode '0640'
  owner 'root'
  group 'placement'

  variables(
    processes: placement_processes
  )
end
