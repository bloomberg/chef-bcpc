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

# This is a custom resource used to create/update users in ProxySQL's
# 'mysql_users' table.
#
# See https://docs.chef.io/custom_resources_notes/#custom-resources for
# additional information.

# Username and password of the user to create
property :user, Hash
# Host of the ProxySQL service to update
property :host, String, default: node['bcpc']['proxysql']['host']
# Port of the ProxySQL service to update
property :port, Integer, default: node['bcpc']['proxysql']['port']
# Admin port of the ProxySQL service to update
property :admin_port, Integer, default: node['bcpc']['proxysql']['admin_port']
# ProxySQL admin username and password
property :psqladmin, Hash

action :create do
  # Declare the resource containing the SQL query to create/update a mysql user
  file '/tmp/proxysql-create-mysql-user.sql' do
    action :delete
  end

  # Create the SQL query used to create/update a mysql user
  # User creation/modification is skipped if a user with the specified username
  # and password already exists and user-specific configuration options have
  # not changed.
  template '/tmp/proxysql-create-mysql-user.sql' do
    cookbook 'bcpc'
    source 'proxysql/proxysql-create-mysql-user.sql.erb'
    variables(
      username: new_resource.user['username'],
      password: new_resource.user['password']
    )
    not_if "mysql -u #{new_resource.user['username']} \
      -p${MYSQL_PWD} \
      -h #{new_resource.host} \
      -P #{new_resource.port} -e 'SHOW DATABASES;' \
      && [ \"#{node.run_state['proxysql_update_users']}\" != \"true\" ] \
    ", environment: { 'MYSQL_PWD' => new_resource.user['password'] }
    notifies :run, 'execute[create mysql user]', :immediately
    notifies :delete, 'file[/tmp/proxysql-create-mysql-user.sql]', :immediately
  end

  # Create/update the specified user in ProxySQL's mysql_user table.
  # NOTE: Users are first deleted from the in-memory configuration and then
  # inserted (percona's proxysql-admin script does the same). Old users are not
  # deleted.
  execute 'create mysql user' do
    action :nothing
    environment('MYSQL_PWD' => new_resource.psqladmin['password'])
    command "mysql -u #{new_resource.psqladmin['username']} \
      -p${MYSQL_PWD} \
      -h #{new_resource.host} \
      -P #{new_resource.admin_port} < /tmp/proxysql-create-mysql-user.sql"
    retries 8
  end
end
