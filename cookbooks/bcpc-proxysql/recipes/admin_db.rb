#
# Cookbook Name:: bcpc-proxysql
# Recipe:: admin_db
#
# Copyright 2016, Bloomberg Finance L.P.
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

# Update ProxySQL admin database directly as not every setting can be loaded
# from /etc/proxysql.cnf
bcpc_proxysql_adminsql 'force-transaction-persistence' do
  query 'UPDATE mysql_users SET transaction_persistent = 1;'
end

bcpc_proxysql_adminsql 'setup-proxysql-hostgroups' do
  query "REPLACE INTO mysql_replication_hostgroups VALUES ( \
    #{node['bcpc-proxysql']['hostgroups']['writer']}, \
    #{node['bcpc-proxysql']['hostgroups']['reader']}, 'bcpc');"
end

node['bcpc-proxysql']['mysql_variables'].each do |k, v|
  bcpc_proxysql_adminsql "set-global-variable-#{k}" do
    query "UPDATE global_variables SET variable_value = '#{v}' WHERE \
      variable_name = 'mysql-#{k}';"
  end
end

node['bcpc-proxysql']['generated']['mysql_servers'].each do |server|
  bcpc_proxysql_adminsql "update-mysql_servers-for-#{server['address']}" do
    query "UPDATE mysql_servers SET \
           port = #{server['port']}, \
           weight = #{server['weight']}, \
           max_connections = #{server['max_connections']} , \
           max_latency_ms = #{server['max_latency_ms']} \
           WHERE hostname = '#{server['address']}';"
  end
end

bcpc_proxysql_adminsql 'setup-scheduler-for-backend-health-checks' do
  query "REPLACE INTO scheduler VALUES (1, 1, \
    #{node['bcpc-proxysql']['check']['interval']}, \
    '#{node['bcpc-proxysql']['check']['script']}', \
    #{node['bcpc-proxysql']['hostgroups']['writer']}, \
    #{node['bcpc-proxysql']['hostgroups']['reader']}, \
    #{node['bcpc-proxysql']['check']['writers']}, \
    #{node['bcpc-proxysql']['check']['writers_are_readers']}, \
    '#{node['bcpc-proxysql']['check']['logfile']}', 'bcpc');"
end
# end ProxySQL admin database updates

# Load configurations to runtime and save to SQLite
['mysql users', 'mysql servers', 'mysql variables', 'scheduler'].each do |c|
  bcpc_proxysql_adminsql "load-and-save-#{c}-config" do
    query "LOAD #{c} TO RUNTIME; SAVE #{c} TO DISK;"
  end
end
