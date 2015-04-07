#
# Cookbook Name:: bcpc
# Recipe:: cassandra
#
# Copyright 2013, Bloomberg Finance L.P.
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

include_recipe "bcpc::default"

apt_repository "cassandra" do
    uri node['bcpc']['repos']['cassandra']
    distribution "12x"
    components ["main"]
    key "cassandra.key"
end

package "cassandra" do
    action :upgrade
    notifies :stop, "service[cassandra]", :immediately
    notifies :run, "bash[remove-initial-cassandra-data-dir]", :immediately
end

bash "remove-initial-cassandra-data-dir" do
    action :nothing
    user "root"
    code <<-EOH
        TIMESTAMP=`date +%Y%m%d-%H%M%S`
        mv /var/lib/cassandra /var/lib/cassandra.$TIMESTAMP
        mkdir /var/lib/cassandra
        chown cassandra:cassandra /var/lib/cassandra
    EOH
end

%w{cassandra-env.sh cassandra-rackdc.properties cassandra.yaml}.each do |file|
    template "/etc/cassandra/#{file}" do
        source "#{file}.erb"
        mode 00644
        variables(:servers => get_head_nodes)
        notifies :restart, "service[cassandra]", :delayed
    end
end

service "cassandra" do
    action [:enable, :start]
    restart_command "service cassandra stop && service cassandra start && sleep 5"
end
