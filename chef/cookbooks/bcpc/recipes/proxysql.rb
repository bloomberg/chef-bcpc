# Cookbook:: bcpc
# Recipe:: proxysql
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

# Remove old Percona-based ProxySQL if service is not enabled
# TODO: Remove me once enough time has passed since the default package has been
# changed to ProxySQL 2.2.
package 'remove proxysql2' do
  package_name 'proxysql2'
  action :purge
  not_if { node['bcpc']['proxysql']['enabled'] }
end

# Remove ProxySQL if it is not enabled
package 'remove proxysql' do
  package_name 'proxysql'
  action :purge
  not_if { node['bcpc']['proxysql']['enabled'] }
end

return unless node['bcpc']['proxysql']['enabled']

##########
# Hashes #
##########

# Pull in various values to be used later
region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
mysqladmin = mysqladmin()
psqladmin = psqladmin()

# hash defining the mysql monitor user used by ProxySQL
#
proxysqlmonitor = {
  'username' => config['proxysql']['creds']['db']['username'],
  'password' => config['proxysql']['creds']['db']['password'],
}

# hash containing backend server options
#
mysqlbackend = {
  'port' => node['bcpc']['mysql']['port'],
  'local_weight' => node['bcpc']['proxysql']['mysql_servers']['local_weight'],
  'remote_weight' => node['bcpc']['proxysql']['mysql_servers']['remote_weight'],
  'compression' => node['bcpc']['proxysql']['mysql_servers']['compression'],
  'max_connections' => node['bcpc']['proxysql']['mysql_servers']['max_connections'],
  'max_replication_lag' => node['bcpc']['proxysql']['mysql_servers']['max_replication_lag'],
  'use_ssl' => node['bcpc']['proxysql']['mysql_servers']['use_ssl'],
  'max_latency_ms' => node['bcpc']['proxysql']['mysql_servers']['max_latency_ms'],
}

################
# Installation #
################

# Define the repository to use
repo = node['bcpc']['proxysql']['repo']

# Add the specified repository
apt_repository 'proxysql' do
  uri repo['url']
  distribution repo['distribution']
  components ['main']
  key repo['key']
  only_if { repo['enabled'] }
end

# Install ProxySQL
#
# NOTE: When ProxySQL is first installed it is not automatically started.
# In order to force ProxySQL to re-read its configuration file we need to
# either delete its database or start the process using the 'initial' flag.
# The latter can be done via the proxysql-initial.service systemd target.
package 'proxysql' do
  notifies :run, 'ruby_block[set proxysql fresh install]', :immediately
end

# Set a flag indicating ProxySQL was freshly installed
ruby_block 'set proxysql fresh install' do
  action :nothing
  block do
    node.run_state['proxysql_fresh_install'] = true
  end
end

# Delete the ProxySQL configuration DB
execute 'delete default proxysql config db' do
  command "rm -f #{node['bcpc']['proxysql']['default_datadir']}/proxysql.db"
  only_if { node.run_state['proxysql_fresh_install'] }
end

# Declare the service resource
service 'proxysql'

#########################
# psql_monitor creation #
#########################

# Declare the resource containing the SQL query to create/update the
# psql_monitor user
# NOTE: We need to ensure that this file is deleted before the following
# template resource is executed because if the latter fails after creating said
# file other resources will not be notified (including a theoretical delete
# action on said resource) and subsequent runs will skip the template.
file '/tmp/proxysql-create-monitor-user.sql' do
  action :delete
end

# Create the SQL query used to create/update the psql_monitor user.
# User creation/modification is skipped if a user with the specified username
# and password already exists.
# NOTE: We cannot use node['bcpc']['proxysql']['host'] because there may not be
# any ProxySQL servers set up yet.
template '/tmp/proxysql-create-monitor-user.sql' do
  source 'proxysql/proxysql-create-monitor-user.sql.erb'
  variables(
    db: proxysqlmonitor
  )
  not_if "mysql -u #{proxysqlmonitor['username']} \
    -p${MYSQL_PWD} \
    -h #{node['hostname']} \
    -P #{node['bcpc']['mysql']['port']} -e 'SHOW DATABASES;' \
  ", environment: { 'MYSQL_PWD' => proxysqlmonitor['password'] }
  notifies :run, 'execute[create psql_monitor user]', :immediately
end

# Create/update the psql_monitor user on the mysql cluster if needed.
# NOTE: The created user has 'USAGE' permissions to all databases, the same as
# if we created it using the Percona admin script. Password updates are
# propagated and username changes result in new users. Old users are not
# deleted. May connect via % and localhost, like all other mysql users.
execute 'create psql_monitor user' do
  action :nothing
  environment('MYSQL_PWD' => mysqladmin['password'])
  command "mysql -u #{mysqladmin['username']} \
    -p${MYSQL_PWD} \
    -h #{node['hostname']} \
    -P #{node['bcpc']['mysql']['port']} < /tmp/proxysql-create-monitor-user.sql"
  notifies :delete, 'file[/tmp/proxysql-create-monitor-user.sql]', :immediately
end

#######################
# Misc. File Creation #
#######################

# Create a directory containing helper files
directory 'files-dir' do
  action :create
  path "#{node['bcpc']['proxysql']['datadir']}/files"
end

# Create a template describing a script that is to be executed when ProxySQL
# crashes.
template 'log crash script' do
  path "#{node['bcpc']['proxysql']['datadir']}/files/log-crash.sh"
  mode '755'
  source 'proxysql/log-crash.sh.erb'
end

###########################
# Logrotate Configuration #
###########################

# Create the mysql CLI configuration file containing ProxySQL admin
# credentials. This file is used by the logrotate script, but can also be used
# to quickly connect to the local ProxySQL server.
template 'mysql cnf for proxysql admin' do
  path '/etc/proxysql-admin.cnf'
  source 'proxysql/proxysql-admin.cnf.erb'
  variables(
    creds: config['proxysql']['creds'],
    backend: mysqlbackend,
    mysql_users: config['mysql']['users'],
    query_rules: node['bcpc']['proxysql']['query_rules']
  )
end

# Create the logrotate file that will rotate all ProxySQL log files.
# NOTE: This will (and must) overwrite the one provided by the package.
logrotate_app 'proxysql' do
  path "#{node['bcpc']['proxysql']['datadir']}/*.log"
  frequency 'daily'
  options %w(missingok compress notifempty)
  rotate 15
  create '0600 proxysql proxysql'
  postrotate 'mysql --defaults-file=/etc/proxysql-admin.cnf -Nse "PROXYSQL FLUSH LOGS"'
end

#########################
# Service Configuration #
#########################

# Create a template containing the values of variables that, when changed,
# require ProxySQL to be restarted in order to take effect.
template 'variables requiring restart' do
  path "#{node['bcpc']['proxysql']['datadir']}/files/vars-restart"
  source 'proxysql/vars-restart.erb'
  notifies :run, 'ruby_block[set restart after config flag]', :immediately
end

# Create a template containing the values of variables that, when changed,
# require users not defined in ProxySQL's configuration file to be updated.
template 'user variables' do
  path "#{node['bcpc']['proxysql']['datadir']}/files/vars-user"
  source 'proxysql/vars-user.erb'
  notifies :run, 'ruby_block[set user update flag]', :immediately
end

# Set a flag indicating proxysql needs to be restarted after the configuration
# is written to the database.
ruby_block 'set restart after config flag' do
  action :nothing
  block do
    node.run_state['proxysql_restart_after_config'] = true
  end
end

# Set a flag indicating ProxySQL users not defined in the ProxySQL config need
# to be updated.
node.run_state['proxysql_update_users'] = false
ruby_block 'set user update flag' do
  action :nothing
  block do
    node.run_state['proxysql_update_users'] = true
  end
end

# Update ProxySQL's configuration file
# NOTE: If the service needs to be restarted it should be restarted before
# the configuration is reloaded in case values like the admin password changed.
template '/etc/proxysql.cnf' do
  source 'proxysql/proxysql.cnf.erb'
  variables(
    headnodes: headnodes(all: true),
    creds: config['proxysql']['creds'],
    backend: mysqlbackend,
    mysql_users: config['mysql']['users'],
    query_rules: node['bcpc']['proxysql']['query_rules']
  )
  notifies :start, 'service[proxysql conditional start]', :immediately
  notifies :run, 'bcpc_proxysql_reload[reload config]', :immediately
  notifies :restart, 'service[proxysql conditional restart]', :immediately
end

# Start ProxySQL iff 'proxysql_fresh_install' was set
service 'proxysql conditional start' do
  service_name 'proxysql'
  action :nothing
  only_if { node.run_state['proxysql_fresh_install'] }
end

########################
# Reload Configuration #
########################

# Custom resource used to propagate changes to ProxySQL's configuration file
# and in-memory tables to disk and runtime.
bcpc_proxysql_reload 'reload config' do
  host node['hostname']
  psqladmin psqladmin
  action :nothing
end

# Restart ProxySQL iff 'proxysql_restart_after_config' was set
# (some configuration changes require a restart)
service 'proxysql conditional restart' do
  service_name 'proxysql'
  action :nothing
  only_if { node.run_state['proxysql_restart_after_config'] }
end

###########
# Cluster #
###########

# If ProxySQL was just installed an not the primary server we want to first
# sync its configuration with the existing ProxySQL cluster (of which the
# primary is a part), and then add ourselves to the cluster. Otherwise we run
# the risk of nodes already in the cluster updating themselves with the
# configuration of the newly added node and clearing additions to mysql_users
# and other synced tables.
#
# NOTE: We assume that the ProxySQL primary does not change to this newly
# created server until at least after it joins the cluster. This should be a
# safe assumption since only a ProxySQL failure would result in the primary
# moving.
#
# See https://proxysql.com/documentation/Proxysql-Cluster/ for additional
# information.

# Wait for consul to elect the ProxySQL primary and for the reverse DNS entry
# to be populated. This avoids race conditions both in this recipe and
# elsewhere.
execute 'wait for consul to elect the primary proxysql host' do
  retries 30
  command "getent hosts #{node['bcpc']['proxysql']['host']} && \
    host #{node['bcpc']['proxysql']['host']}"
end

# Fetch the ProxySQL primary's IP
proxysql_primary_ip = ''
ruby_block 'get proxysql primary IP' do
  block do
    Chef::Resource::RubyBlock.include Chef::Mixin::ShellOut
    cmd = "host #{node['bcpc']['proxysql']['host']} \
      | awk '{print $NF}'"
    cmd = shell_out(cmd)
    proxysql_primary_ip = cmd.stdout.chomp()
  end
end

# Add the ProxySQL primary as a peer iff we just installed ProxySQL and are
# not the primary. If we are the ProxySQL primary we are the first ProxySQL
# and thus there is no existing cluster to add ourselves to.
bcpc_proxysql_peer 'add primary as a peer' do
  psqladmin psqladmin
  ip node['service_ip']
  peer_ip lazy { proxysql_primary_ip }
  only_if { node.run_state['proxysql_fresh_install'] }
  not_if { proxysql_primary_ip == node['service_ip'] }
  notifies :run, 'bcpc_proxysql_reload[reload config]', :immediately
  notifies :run, 'execute[wait for proxysql sync]', :immediately
end

# Wait 2 sync cycles to ensure that the configuration of the existing ProxySQL
# cluster has been pulled in and applied.
# NOTE: We cannot be sure whether or not the server's configuration actually
# is divergent from that of the cluster, thus we simply wait instead of
# checking whether some specific values were synced.
# NOTE: Replace with 'chef_sleep' if move to chef >= 15.5
sync_sleep = (node['bcpc']['proxysql']['cluster_diffs_before_sync'] *
              node['bcpc']['proxysql']['cluster_check_interval_ms'] * 2.0) / 1000
execute 'wait for proxysql sync' do
  action :nothing
  command "sleep #{sync_sleep}"
  notifies :create, 'bcpc_proxysql_peer[add as peer to primary]', :immediately
end

# Add ourselves to the existing ProxySQL cluster by adding ourselves as a
# peer to the primary.
bcpc_proxysql_peer 'add as peer to primary' do
  action :nothing
  psqladmin psqladmin
  ip lazy { proxysql_primary_ip }
  peer_ip node['service_ip']
  comment node['hostname']
  notifies :run, 'bcpc_proxysql_reload[reload primary config]', :immediately
end

# Reload the primary ProxySQL's config
bcpc_proxysql_reload 'reload primary config' do
  action :nothing
  psqladmin psqladmin
end
