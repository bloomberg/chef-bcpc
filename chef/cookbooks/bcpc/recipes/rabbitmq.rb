# Cookbook:: bcpc
# Recipe:: rabbitmq
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

apt_repository 'rabbitmq' do
  uri node['bcpc']['rabbitmq']['source']['repo']['url']
  components ['main']
  key 'rabbitmq/rabbitmq.key'
  only_if { node['bcpc']['rabbitmq']['source']['repo']['enabled'] }
end

template '/etc/apt/preferences.d/99rabbitmq' do
  source 'rabbitmq/apt-preferences.erb'
  variables(
    release: node['bcpc']['rabbitmq']['source']['distribution']['name']
  )
  only_if { node['bcpc']['rabbitmq']['source']['distribution']['enabled'] }
end

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

package 'rabbitmq-server'

service 'rabbitmq-server'
service 'xinetd'

cookbook_file '/etc/sudoers.d/rabbitmqctl' do
  source 'rabbitmq/sudoers'
  mode '440'
end

template '/etc/rabbitmq/rabbitmq-env.conf' do
  source 'rabbitmq/rabbitmq-env.conf.erb'
  mode '644'
end

directory '/etc/rabbitmq/rabbitmq.conf.d' do
  action :create
end

template '/etc/rabbitmq/rabbitmq.conf.d/bcpc.conf' do
  source 'rabbitmq/bcpc.conf.erb'
  notifies :restart, 'service[rabbitmq-server]', :delayed
end

template '/etc/default/rabbitmq-server' do
  source 'rabbitmq/default.erb'
  notifies :restart, 'service[rabbitmq-server]', :delayed
end

file '/var/lib/rabbitmq/.erlang.cookie' do
  mode '400'
  content config['rabbit']['cookie']
  notifies :restart, 'service[rabbitmq-server]', :delayed
end

execute 'enable rabbitmq web mgmt' do
  command '/usr/sbin/rabbitmq-plugins enable rabbitmq_management'
  not_if '/usr/sbin/rabbitmq-plugins list -m -e | grep "^rabbitmq_management$"'
  notifies :restart, 'service[rabbitmq-server]', :delayed
end

template '/etc/rabbitmq/rabbitmq.config' do
  source 'rabbitmq/rabbitmq.config.erb'
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

begin
  # add this node to the existing rabbitmq cluster if one exists
  unless init_rmq?
    members = rmqnodes(exclude: node['hostname'])

    hosts = members.collect do |m|
      "rabbit@#{m['hostname']}"
    end

    hosts = hosts.join(' ')

    bash 'join rabbitmq cluster' do
      code <<-DOC
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

        # get rabbit cluster status in json format
        #
        rcs=$(rabbitmqctl cluster_status --formatter json)

        # check to see if we're already a member
        #
        if echo ${rcs} | \
            jq -e --arg m ${member} '.running_nodes[] | select(. == $m)'; then
          echo "#{node['hostname']} is already a member of this cluster"
          exit 0
        fi

        # try to register this node with the cluster
        #
        rabbitmqctl stop_app
        rabbitmqctl reset
        rabbitmqctl join_cluster ${member}
        rabbitmqctl start_app
      DOC
    end
  end
end

execute 'wait for rabbitmq to come online' do
  retries 30
  command 'rabbitmqctl list_users'
end

execute 'set rabbitmq user password' do
  username = config['rabbit']['username']
  password = config['rabbit']['password']
  command "rabbitmqctl change_password #{username} #{password}"
end

# Use n/2+1 queue mirrors as long as we have at least three rmqnodes.
# If we have fewer than three rmqnodes, fallback to ha-all.
rmqnodes = rmqnodes(all: true)
ha_exactly = { 'ha-mode' => 'exactly', 'ha-params' => rmqnodes.length / 2 + 1 }
ha_all = { 'ha-mode': 'all' }

ha_policy = rmqnodes.length >= 3 ? ha_exactly : ha_all

execute 'set rabbitmq ha policy' do
  command <<-DOC
    rabbitmqctl set_policy HA '^(?!(amq\.|[a-f0-9]{32})).*' '#{ha_policy.to_json}'
  DOC
end

cookbook_file '/usr/local/bin/rabbitmqcheck' do
  source 'rabbitmq/rabbitmq-check'
  mode '755'
end

execute 'add amqpchk to etc services' do
  command <<-DOC
    printf 'amqpchk\t5673/tcp\n' >> /etc/services
  DOC
  not_if 'grep amqpchk /etc/services'
end

template '/etc/xinetd.d/amqpchk' do
  source 'rabbitmq/xinetd-amqpchk.erb'
  mode '640'

  variables(
    only_from: primary_network_aggregate_cidr
  )

  notifies :restart, 'service[xinetd]', :immediately
end
