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

unified_mode true

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
  # Declare the resource containing the SQL query to create/update a MySQL user
  file '/tmp/proxysql-create-mysql-user.sql' do
    action :delete
  end

  # Create the SQL query used to create/update a MySQL user. If the user does
  # not exist it is created. If it does exist and needs to be updated, it is
  # deleted and recreated.
  #
  # NOTE: In order to determine whether or not a user exists we attempt to
  # access a MySQL database as the said user via ProxySQL. This has the added
  # benefit of checking whether or not the password has been updated (passwords
  # are stored in hashed form by ProxySQL, plaintext in the props). Lastly we
  # query ProxySQL for changeable fields and compare them against those in the
  # props.
  #
  # This method does not rely on any other recipe (e.g. a global flag set in
  # proxysql.rb) executing beforehand, and thus is more intuitive.
  #
  # NOTE: If the number of ProxySQL user properties we allow to be modified
  # changes, the sql query listed below should be updated.
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
      && [ \"$(mysql --defaults-file=/etc/proxysql-admin.cnf -Nse \
            \"SELECT use_ssl, transaction_persistent, fast_forward, \
            max_connections FROM mysql_users WHERE \
            username='#{new_resource.user['username']}' AND frontend=1;\" \
        | sed 's/\t/,/g')\" = \"\
#{node['bcpc']['proxysql']['mysql_users']['use_ssl']},\
#{node['bcpc']['proxysql']['mysql_users']['transaction_persistent']},\
#{node['bcpc']['proxysql']['mysql_users']['fast_forward']},\
#{node['bcpc']['proxysql']['mysql_users']['max_connections']}\" ] \
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
