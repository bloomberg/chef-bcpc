# Cookbook:: bcpc
# Recipe:: rabbitmq
#
# Copyright:: 2023 Bloomberg Finance L.P.
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
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

template '/etc/default/rabbitmq-server' do
  source 'rabbitmq/default.erb'
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

file '/var/lib/rabbitmq/.erlang.cookie' do
  mode '400'
  content config['rabbit']['cookie']
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

execute 'enable rabbitmq web mgmt' do
  command '/usr/sbin/rabbitmq-plugins enable rabbitmq_management'
  not_if '/usr/sbin/rabbitmq-plugins list -m -e | grep "^rabbitmq_management$"'
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

template '/etc/rabbitmq/rabbitmq.config' do
  source 'rabbitmq/rabbitmq.config.erb'
  notifies :restart, 'service[rabbitmq-server]', :immediately
end

begin
  # add this node to the existing rabbitmq cluster if one exists
  unless init_rmq?
    members = rmqnodes(exclude: node['hostname'])
    username = config['rabbit']['username']
    password = config['rabbit']['password']

    hosts = members.collect do |m|
      "rabbit@#{m['hostname']}"
    end

    hosts = hosts.join(' ')
    healthcheck_path = if node['platform_version'] == '20.04'
                         '/api/healthchecks/node'
                       else
                         '/api/health/checks/alarms'
                       end

    bash 'join rabbitmq cluster' do
      code <<-DOC
        set -o pipefail
        unset http_proxy
        unset https_proxy

        # try to find a healthy cluster member
        #
        member=''

        for h in #{hosts}; do
          status=$(curl -su '#{username}:#{password}' "http://${h}:55672#{healthcheck_path}")
          if echo ${status} | jq -e 'select(.status == "ok")'; then
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

if node['bcpc']['nova']['notifications']['format'] != 'unversioned'
  # Nova versioned messages are enabled only for Watcher to be able to consume
  # them. Messages remain in the queue even after Watcher has consumed them.
  # This is because Watcher subscribes to the queue using the 'pool' option
  # from the oslo_messaging. In order to prevent the queue from growing
  # infinitely, we need to set a rabbitmq policy so that messages in the queue
  # expire after a pre-defined time interval.
  new_versioned_queue_policy = ha_policy.clone
  new_versioned_queue_policy['message-ttl'] = node['bcpc']['rabbitmq'][
    'message_ttl']['watcher']

  # get the current policy settings for versioned notifications
  begin
    current_versioned_policy = JSON.parse(
      shell_out!(
        'rabbitmqctl list_policies --formatter json | jq -r \
        \'.[] | select(.pattern == "^watcher_notifications.*")
        | .definition\''
      ).stdout.strip
    )
  rescue
    current_versioned_policy = {}
  end

  # set the rabbitmq policy to define message-ttl
  execute 'set ha and ttl policy for nova notification queues consumed by Watcher' do
    command <<-DOC
      rabbitmqctl set_policy "HA and TTL for queues that Watcher consumes" \
        '^watcher_notifications.*' \
        '#{new_versioned_queue_policy.to_json}' \
        --apply-to queues --priority 1
    DOC
    only_if { current_versioned_policy.to_json != new_versioned_queue_policy.to_json }
  end

  current_versioned_message_ttl = current_versioned_policy['message-ttl']

  # If the earlier policy did not set a message-ttl, purge the queues so that
  # messages with no ttl defined do not exist in the queue.
  ['watcher_notifications.info', 'watcher_notifications.error'].each do |queue|
    execute "purge existing messages from #{queue}" do
      command <<-DOC
        rabbitmqctl purge_queue #{queue}
      DOC
      returns [0, 69]
      only_if { current_versioned_message_ttl.nil? }
    end
  end
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
