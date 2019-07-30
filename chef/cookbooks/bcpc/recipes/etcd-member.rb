# Cookbook:: bcpc
# Recipe:: etcd-member
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

include_recipe 'bcpc::etcd-packages'
include_recipe 'bcpc::etcd-ssl'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

etcd_users = config['etcd']['users']
root = etcd_users.find { |user| user['username'] == 'root' }
server = etcd_users.find { |user| user['username'] == 'server' }
client_ro = etcd_users.find { |user| user['username'] == 'client-ro' }
client_rw = etcd_users.find { |user| user['username'] == 'client-rw' }

# joined state file
etcd_joined_file = '/var/lib/etcd/joined'

service 'etcd'

directory '/var/lib/etcd' do
  action :create
  recursive true
end

begin
  # attempt to register this node with an existing etcd cluster if one exists
  unless init_cloud?

    members = headnodes(exclude: node['hostname'])
    endpoints = members.map { |m| "#{m['service_ip']}:2379" }.join(' ')

    bash "try to add #{node['hostname']} to existing etcd cluster" do
      environment etcdctl_env
      creates etcd_joined_file
      code <<-DOC
        member=''

        # try to find a healthy cluster member
        #
        for e in #{endpoints}; do
          if etcdctl --endpoints ${e} endpoint health; then
            member=${e}
            break
          fi
        done

        # exit if we don't find a healthy member
        #
        [ -z "$member" ] && exit 1

        # check to see if we're already a member
        #
        member_list=$(etcdctl --endpoints ${member} member list)
        peer_url="https://#{node['service_ip']}:2380"

        if echo ${member_list} | grep ${peer_url}; then
          echo "#{node['fqdn']} is already a member of this cluster"
          exit 0
        fi

        # try to register this node with the cluster
        #
        cmd="etcdctl --endpoints ${member} --peer-urls=${peer_url}"
        cmd="${cmd} member add #{node['fqdn']}"

        if ${cmd}; then
          echo "successfully registered #{node['fqdn']}"
          touch #{etcd_joined_file}
          exit 0
        fi

        echo "failed to register #{node['fqdn']}"
        exit 1
      DOC
    end
  end
end

initial_cluster = []
initial_cluster_state = 'existing'

if init_cloud?
  initial_cluster = "#{node['fqdn']}=https://#{node['service_ip']}:2380"
  initial_cluster_state = 'new'
else
  headnodes = headnodes(exclude: node['hostname'])
  headnodes.push(node)

  initial_cluster = headnodes.collect do |h|
    "#{h['fqdn']}=https://#{h['service_ip']}:2380"
  end

  initial_cluster = initial_cluster.join(',')
end

template '/etc/systemd/system/etcd.service' do
  source 'etcd/etcd.service.erb'
  variables(
    initial_cluster: initial_cluster,
    initial_cluster_state: initial_cluster_state
  )

  notifies :run, 'execute[enable etcd service]', :immediately
  notifies :run, 'execute[reload systemd]', :immediately
  notifies :restart, 'service[etcd]', :immediately
end

execute 'enable etcd service' do
  action :nothing
  command 'systemctl enable etcd.service'
  not_if 'systemctl is-enabled etcd.service'
end

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end

execute 'wait for etcd membership' do
  environment etcdctl_env
  retries 5
  command "etcdctl member list | grep #{node['fqdn']}"
end

execute 'etcd: add root user' do
  environment etcdctl_env
  command "etcdctl user add root:#{root['password']}"
  not_if "etcdctl --user root:#{root['password']} user list | grep -w root"
end

execute 'etcd: enable authentication' do
  environment etcdctl_env
  command "etcdctl --user root:#{root['password']} auth enable"
end

bash 'etcd: create rw role' do
  environment etcdctl_env
  code <<-EOH
    etcdctl --user root:#{root['password']} role add rw
    etcdctl --user root:#{root['password']} role grant-permission rw \
      --prefix=true readwrite /
  EOH
  not_if "etcdctl --user root:#{root['password']} role list | grep -w rw"
end

bash 'etcd: create ro role' do
  environment etcdctl_env
  code <<-EOH
    etcdctl --user root:#{root['password']} role add ro
    etcdctl --user root:#{root['password']} role grant-permission ro \
      --prefix=true read /

    # allow worknodes read/write access to /calico/felix/ so that
    # calico-felix can provide health information via etcd to OpenStack
    etcdctl --user root:#{root['password']} role grant-permission ro \
      --prefix=true readwrite /calico/felix/
  EOH
  not_if "etcdctl --user root:#{root['password']} role list | grep -w ro"
end

bash 'etcd: add server user' do
  environment etcdctl_env
  code <<-EOH
    etcdctl --user root:#{root['password']} \
      user add server:#{server['password']}
    etcdctl --user root:#{root['password']} user grant-role server root
  EOH
  not_if "etcdctl --user root:#{root['password']} user list | grep -w server"
end

bash 'etcd: add client-ro user' do
  environment etcdctl_env
  code <<-EOH
    etcdctl --user root:#{root['password']} \
      user add client-ro:#{client_ro['password']}
    etcdctl --user root:#{root['password']} user grant-role client-ro ro
  EOH
  not_if "
    etcdctl --user root:#{root['password']} user list | grep -w client-ro
  "
end

bash 'etcd: add client-rw user' do
  environment etcdctl_env
  code <<-EOH
    etcdctl --user root:#{root['password']} \
      user add client-rw:#{client_rw['password']}
    etcdctl --user root:#{root['password']} user grant-role client-rw rw
  EOH
  not_if "
    etcdctl --user root:#{root['password']} user list | grep -w client-rw
  "
end
