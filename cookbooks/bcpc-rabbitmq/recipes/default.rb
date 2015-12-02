#
# Cookbook Name:: bcpc-rabbitmq
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'bcpc-xinetd'

ruby_block "initialize-rabbitmq-config" do
    block do
        make_config('rabbitmq-user', "guest")
        make_config('rabbitmq-password', secure_password)
        make_config('rabbitmq-cookie', secure_password)
    end
end

apt_repository "erlang" do
    uri node['bcpc']['repos']['erlang']
    distribution node['lsb']['codename']
    components ["contrib"]
    key "erlang.key"
end

apt_repository "rabbitmq" do
    uri node['bcpc']['repos']['rabbitmq']
    distribution 'testing'
    components ["main"]
    key "rabbitmq.key"
end

%w{
   erlang-base
   erlang-syntax-tools
   erlang-mnesia
   erlang-runtime-tools
   erlang-crypto
   erlang-asn1
   erlang-public-key
   erlang-ssl
   erlang-inets
   erlang-corba
   erlang-diameter
   erlang-xmerl
   erlang-edoc
   erlang-eldap
   erlang-erl-docgen
   erlang-eunit
   erlang-ic
   erlang-inviso
   erlang-odbc
   erlang-snmp
   erlang-os-mon
   erlang-parsetools
   erlang-percept
   erlang-ssh
   erlang-webtool
   erlang-tools
   erlang-nox
}.each do |erlang_package|
  package erlang_package do
    action :install
    version node['bcpc']['erlang']['version']
  end
end

package "rabbitmq-server" do
    action :install
    version node['bcpc']['rabbitmq']['version']
    notifies :stop, "service[rabbitmq-server]", :immediately
end

template "/var/lib/rabbitmq/.erlang.cookie" do
    source "erlang.cookie.erb"
    mode 00400
    notifies :restart, "service[rabbitmq-server]", :immediately
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

template "/etc/default/rabbitmq-server" do
    source "rabbitmq-server-default.erb"
    mode 00644
    owner "root"
    group "root"
    notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/rabbitmq.conf.d/bcpc.conf" do
    source "rabbitmq-bcpc.conf.erb"
    mode 00644
    notifies :restart, "service[rabbitmq-server]", :immediately
end

template "/etc/rabbitmq/rabbitmq.config" do
    source "rabbitmq.config.erb"
    mode 00644
    notifies :restart, "service[rabbitmq-server]", :immediately
end

execute "enable-rabbitmq-web-mgmt" do
    command "/usr/sbin/rabbitmq-plugins enable rabbitmq_management"
    not_if "/usr/sbin/rabbitmq-plugins list -m -e | grep '^rabbitmq_management$'"
    notifies :restart, "service[rabbitmq-server]", :delayed
end

service "rabbitmq-server" do
    stop_command "service rabbitmq-server stop && epmd -kill"
    action [:enable]
    supports :status => true
end

ruby_block "rabbitmq-clustering-lazy-wrapper" do
  block do
    get_head_nodes.each do |server|
      if server['hostname'] != node['hostname']
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
  end
end

ruby_block "set-rabbitmq-guest-password" do
    block do
        %x[ rabbitmqctl change_password "#{get_config('rabbitmq-user')}" "#{get_config('rabbitmq-password')}" ]
    end
end

ruby_block "set-rabbitmq-ha-policy" do
  block do
    min_quorum = get_head_nodes.length/2 + 1
    %x[rabbitmqctl set_policy HA '^(?!(amq\.|[a-f0-9]{32})).*' '{"ha-mode": "all"}']
  end
end

template "/usr/local/bin/rabbitmqcheck" do
    source "rabbitmqcheck.erb"
    mode 0755
    owner "root"
    group "root"
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

template "/etc/sudoers.d/rabbitmqctl" do
    source "sudoers-rabbitmqctl.erb"
    user "root"
    group "root"
    mode 00440
end
