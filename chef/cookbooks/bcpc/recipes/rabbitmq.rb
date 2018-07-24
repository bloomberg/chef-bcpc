# Cookbook Name:: bcpc
# Recipe:: rabbitmq
#
# Copyright 2018, Bloomberg Finance L.P.
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
if node['bcpc']['rabbitmq']['repo']['enabled']
  apt_repository "rabbitmq" do
    uri node['bcpc']['rabbitmq']['repo']['url']
    distribution 'testing'
    components ["main"]
    key "rabbitmq/rabbitmq.key"
  end
end

if node['bcpc']['erlang']['repo']['enabled']
  apt_repository "erlang" do
    uri node['bcpc']['erlang']['repo']['url']
    distribution node['lsb']['codename']
    components ["contrib"]
    key "rabbitmq/erlang.key"
  end
end

apt_repository "erlang" do
    uri node['bcpc']['repos']['erlang']
    distribution node['lsb']['codename']
    components ["contrib"]
    key "erlang.key"
end

apt_preference 'erlang' do
  glob 'erlang*'
  pin 'version 1:20.3-1'
  pin_priority '900'
end

apt_repository "rabbitmq" do
    uri node['bcpc']['repos']['rabbitmq']
    distribution 'testing'
    components ["main"]
    key "rabbitmq.key"
end

package "rabbitmq-server" do
    action :install
    notifies :stop, "service[rabbitmq-server]", :immediately
end

service 'rabbitmq-server'
service 'xinetd'

cookbook_file "/etc/sudoers.d/rabbitmqctl" do
  source "rabbitmq/sudoers"
  mode 00440
end

template "/etc/rabbitmq/rabbitmq-env.conf" do
  source "rabbitmq/rabbitmq-env.conf.erb"
  mode 0644
end

directory "/etc/rabbitmq/rabbitmq.conf.d" do
  action :create
end

template "/etc/rabbitmq/rabbitmq.conf.d/bcpc.conf" do
  source "rabbitmq/bcpc.conf.erb"
  notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/default/rabbitmq-server" do
  source "rabbitmq/default.erb"
  notifies :restart, "service[rabbitmq-server]", :delayed
end

file "/var/lib/rabbitmq/.erlang.cookie" do
  mode 00400
  content "#{config['rabbit']['cookie']}"
  notifies :restart, "service[rabbitmq-server]", :delayed
end

execute "enable rabbitmq web mgmt" do
  command "/usr/sbin/rabbitmq-plugins enable rabbitmq_management"
  not_if "/usr/sbin/rabbitmq-plugins list -m -e | grep '^rabbitmq_management$'"
  notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/rabbitmq.config" do
  source "rabbitmq/rabbitmq.config.erb"
  notifies :restart, "service[rabbitmq-server]", :immediately
end

# add this node to the existing rabbitmq cluster if one exists
#
begin

  if not is_init_cloud()
    members = get_headnodes(exclude: node['hostname'])

    hosts = members.collect{|m|
      "#{'rabbit@' + m['hostname']}"
    }.join(' ')

    bash "join rabbitmq cluster" do
      code <<-EOH
        member=''

        # try to find a healthy cluster member
        #
        for h in #{hosts}; do
          if rabbitmqctl node_health_check -n ${h}; then
            member=${h}
            break
          fi
        done

        # exit if we don't find a healthy member
        #
        [ -z "$member" ] && exit 1

        # check to see if we're already a member
        #
        member_list=$(rabbitmqctl cluster_status | grep running_nodes)

        if echo ${member_list} | grep ${member}; then
          echo "#{node['hostname']} is already a member of this cluster"
          exit 0
        fi

        # try to register this node with the cluster
        #
        rabbitmqctl stop_app
        rabbitmqctl reset
        rabbitmqctl join_cluster ${member}
        rabbitmqctl start_app
      EOH
    end
  end

end

execute 'wait for rabbitmq to come online' do
  retries 30
  command "rabbitmqctl list_users"
end

execute "set rabbitmq user password" do
  username = config['rabbit']['username']
  password = config['rabbit']['password']
  command %Q[rabbitmqctl change_password #{username} #{password}]
end

execute "set rabbitmq ha policy" do
  command <<-EOH
    rabbitmqctl set_policy HA '^(?!(amq\.|[a-f0-9]{32})).*' '{"ha-mode": "all"}'
  EOH
end

cookbook_file "/usr/local/bin/rabbitmqcheck" do
  source "rabbitmq/rabbitmq-check"
  mode 0755
end

execute "add amqpchk to etc services" do
  command <<-EOH
    printf "amqpchk\t5673/tcp\n" >> /etc/services
  EOH
  not_if "grep amqpchk /etc/services"
end

template "/etc/xinetd.d/amqpchk" do
  source "rabbitmq/xinetd-amqpchk.erb"
  mode 00440

  networks = node['bcpc']['networking']['topology']['networks']
  primary = networks['primary']

  variables(
    :only_from => primary['cidr']
  )

  notifies :restart, "service[xinetd]", :immediately
end
