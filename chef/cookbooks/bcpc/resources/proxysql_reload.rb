# Cookbook:: bcpc
# Resource:: proxysql-user
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

# This is a custom resource used to reload the specified ProxySQL's
# configuration.
#
# See https://docs.chef.io/custom_resources_notes/#custom-resources for
# additional information.

# Host of the ProxySQL service to reload the configuration of
property :host, String, default: node['bcpc']['proxysql']['host']
# Port of the ProxySQL service to reload the configuration of
property :admin_port, Integer, default: node['bcpc']['proxysql']['admin_port']
# ProxySQL admin username and password
property :psqladmin, Hash

action :run do
  # Declare the resource containing the SQL query to reload the configuration
  file '/tmp/proxysql-reload-config.sql' do
    action :delete
  end

  # Create the SQL query used to reload the configuration
  template '/tmp/proxysql-reload-config.sql' do
    action :nothing
    cookbook 'bcpc'
    source 'proxysql/proxysql-reload-config.sql.erb'
  end

  # Define the command to be run on configuration file changes.
  # We first load the configuration from the config file into memory, after which
  # they are saved to disk (sqlite db) and finally added to runtime.
  execute 'reload config' do
    environment('MYSQL_PWD' => new_resource.psqladmin['password'])
    command "mysql -u #{new_resource.psqladmin['username']} \
          -p${MYSQL_PWD} \
          -h #{new_resource.host} \
          -P #{new_resource.admin_port} < /tmp/proxysql-reload-config.sql"
    # Need to retry since sometimes this resource is executed immediately after
    # ProxySQL is restarted but not yet available to receive connections
    retries 8
    notifies :create, 'template[/tmp/proxysql-reload-config.sql]', :before
    notifies :delete, 'file[/tmp/proxysql-reload-config.sql]', :immediately
  end
end
