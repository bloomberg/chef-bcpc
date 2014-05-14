#
# Cookbook Name:: bcpc
# Recipe:: rabbitmq
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

ruby_block "initialize-rabbitmq-config" do
    block do
        make_config('rabbitmq-user', "guest")
        make_config('rabbitmq-password', secure_password)
        make_config('rabbitmq-cookie', secure_password)
    end
end

apt_repository "rabbitmq" do
    uri node['bcpc']['repos']['rabbitmq']
    distribution 'testing'
    components ["main"]
    key "rabbitmq.key"
end

package "rabbitmq-server" do
    action :upgrade
    notifies :stop, "service[rabbitmq-server]", :immediately
end

template "/var/lib/rabbitmq/.erlang.cookie" do
    source "erlang.cookie.erb"
    mode 00400
    notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/rabbitmq-env.conf" do
    source "rabbitmq-env.conf.erb"
    mode 0644
end

directory "/etc/rabbitmq/rabbitmq.conf.d" do
    mode 00755
    owner "root"
    group "root"
end

template "/etc/rabbitmq/rabbitmq-env.conf" do
    source "rabbitmq-env.conf.erb"
    mode 0644
end

directory "/etc/rabbitmq/rabbitmq.conf.d" do
    mode 00755
    owner "root"
    group "root"
end

template "/etc/rabbitmq/rabbitmq.conf.d/bcpc.conf" do
    source "rabbitmq-bcpc.conf.erb"
    mode 00644
    notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/rabbitmq.config" do
    source "rabbitmq.config.erb"
    mode 00644
    notifies :restart, "service[rabbitmq-server]", :delayed
end

execute "enable-rabbitmq-web-mgmt" do
    command "/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management"
    not_if "/usr/lib/rabbitmq/bin/rabbitmq-plugins list -e | grep rabbitmq_management"
    notifies :restart, "service[rabbitmq-server]", :delayed
end

bash "rabbitmq-stop" do
    user "root"
    action :nothing
    code <<-EOH
        service rabbitmq-server stop
        epmd -kill
    EOH
end

service "rabbitmq-server" do
    stop_command "service rabbitmq-server stop && epmd -kill"
    action [ :enable, :start ]
end

get_head_nodes.each do |server|
    if server['hostname'] != node[:hostname]
        bash "rabbitmq-clustering-with-#{server['hostname']}" do
            code <<-EOH
                rabbitmqctl stop_app
                rabbitmqctl reset
                rabbitmqctl join_cluster rabbit@#{server['hostname']}
                rabbitmqctl start_app
            EOH
            not_if "rabbitmqctl cluster_status | grep rabbit@#{server['hostname']}"
        end
    end
end

ruby_block "set-rabbitmq-guest-password" do
    block do
        %x[ rabbitmqctl change_password "#{get_config('rabbitmq-user')}" "#{get_config('rabbitmq-password')}" ]
    end
end

bash "set-rabbitmq-ha-policy" do
    min_quorum = get_head_nodes.length/2 + 1
    code <<-EOH
        rabbitmqctl set_policy HA '^(?!(amq\.|[a-f0-9]{32})).*' '{"ha-mode": "exactly", "ha-params": #{min_quorum}}'
    EOH
end

template "/usr/local/bin/rabbitmqcheck" do
    source "rabbitmqcheck.erb"
    mode 0755
    owner "root"
    group "root"
end

package "xinetd" do
    action :upgrade
end

bash "add-amqpchk-to-etc-services" do
    user "root"
    code <<-EOH
        printf "amqpchk\t5673/tcp\n" >> /etc/services
    EOH
    not_if "grep amqpchk /etc/services"
end

template "/etc/xinetd.d/amqpchk" do
    source "xinetd-amqpchk.erb"
    owner "root"
    group "root"
    mode 00440
    notifies :restart, "service[xinetd]", :immediately
end

service "xinetd" do
    action [ :enable, :start ]
end

ruby_block "reap-dead-rabbitmq-servers" do
    block do
        head_names = get_head_nodes.collect{|x| x['hostname']}
        status = %x[ rabbitmqctl cluster_status | grep nodes | grep disc ].strip
        status.scan(/(?:'rabbit@([a-zA-Z0-9-]+)',?)+?/).each do |server|
            if not head_names.include?(server[0])
                %x[ rabbitmqctl forget_cluster_node rabbit@#{server[0]} ]
            end
        end
    end
end
