# Cookbook:: bcpc
# Resource:: proxysql-peer
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

# This is a custom resource used to add the specified ProxySQL server as a peer
# of another ProxySQL server.
#
# See https://docs.chef.io/custom_resources_notes/#custom-resources for
# additional information.

# IP and port of the ProxySQL service to add a peer to
property :ip, String, default: lazy { node['service_ip'] }
property :port, Integer, default: node['bcpc']['proxysql']['admin_port']
# IP and port of the ProxySQL peer to add
property :peer_ip, String
property :peer_port, Integer, default: node['bcpc']['proxysql']['admin_port']
# Comment associated with the peer
property :comment, String
# ProxySQL admin username and password
property :psqladmin, Hash

action :create do
  # Declare the resource containing the SQL query used to add the specified
  # ProxySQL server as a peer.
  file '/tmp/proxysql-add-peer.sql' do
    action :delete
  end

  # Create the SQL template mentioned above
  template '/tmp/proxysql-add-peer.sql' do
    source 'proxysql/proxysql-add-peer.sql.erb'
    variables(
      peer_ip: new_resource.peer_ip,
      peer_port: new_resource.peer_port,
      comment: new_resource.comment
    )
    notifies :run, 'execute[add peer]', :immediately
  end

  # Add the peer
  execute 'add peer' do
    action :nothing
    environment('MYSQL_PWD' => psqladmin['password'])
    command "mysql -u #{psqladmin['username']} \
      -p${MYSQL_PWD} \
      -h #{new_resource.ip} \
      -P #{new_resource.port} < /tmp/proxysql-add-peer.sql"
    notifies :delete, 'file[/tmp/proxysql-add-peer.sql]', :immediately
    retries 8
  end
end
