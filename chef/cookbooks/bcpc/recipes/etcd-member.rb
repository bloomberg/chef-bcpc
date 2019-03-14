# Cookbook Name:: bcpc
# Recipe:: etcd-member
#
# Copyright 2019, Bloomberg Finance L.P.
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

etcdctl_env = {
  'ETCDCTL_API' => '3'
}

if node['bcpc']['etcd']['ssl']['enabled']
  etcdctl_env = etcdctl_env.merge({
    'ETCDCTL_CACERT' => '/etc/etcd/ssl/ca.pem',
    'ETCDCTL_CERT' => '/etc/etcd/ssl/client.pem',
    'ETCDCTL_KEY' => '/etc/etcd/ssl/client-key.pem'
  })
end

etcd_scheme = node['bcpc']['etcd']['scheme']

begin
  # attempt to register this node with an existing etcd cluster if one exists
  unless init_cloud?

    members = headnodes(exclude: node['hostname'])
    endpoints = members.map { |m| "#{m['service_ip']}:2380" }.join(' ')

    bash "try to add #{node['hostname']} to existing etcd cluster" do
      environment etcdctl_env
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
        peer_url="#{etcd_scheme}://#{node['service_ip']}:2380"

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
          exit 0
        fi

        echo "failed to register #{node['fqdn']}"
        exit 1
      DOC
    end
  end
end

systemd_unit 'etcd.service' do
  action %i(create enable restart)

  initial_cluster = []
  initial_cluster_state = 'existing'

  if init_cloud?
    initial_cluster = "#{node['fqdn']}=#{etcd_scheme}://#{node['service_ip']}:2380"
    initial_cluster_state = 'new'
  else
    headnodes = headnodes(exclude: node['hostname'])
    headnodes.push(node)

    initial_cluster = headnodes.collect do |h|
      "#{h['fqdn']}=#{etcd_scheme}://#{h['service_ip']}:2380"
    end

    initial_cluster = initial_cluster.join(',')
  end

  if node['bcpc']['etcd']['ssl']['enabled']
    ssl_args = <<-END_SSL.gsub(/^\s+/, '')
      --client-cert-auth --peer-auto-tls \\
      --trusted-ca-file=/etc/etcd/ssl/ca.pem \\
      --cert-file=/etc/etcd/ssl/server.pem \\
      --key-file=/etc/etcd/ssl/server-key.pem \\
    END_SSL

    etcdctl_env = {
      'ETCDCTL_API' => '3',
      'ETCDCTL_CACERT' => '/etc/etcd/ssl/ca.pem',
      'ETCDCTL_CERT' => '/etc/etcd/ssl/client.pem',
      'ETCDCTL_KEY' => '/etc/etcd/ssl/client-key.pem'
    }
  else
    ssl_args = ''
  end

  content <<-DOC.gsub(/^\s+/, '')
    [Unit]
    Description=etcd - highly-available key value store
    Documentation=https://github.com/coreos/etcd
    After=network.target
    Wants=network-online.target

    [Service]
    Type=notify
    Environment=data_dir=/var/lib/etcd
    ExecStartPre=/bin/mkdir -p ${data_dir}
    Restart=always
    RestartSec=5s
    LimitNOFILE=40000
    TimeoutStartSec=0

    ExecStart=/usr/local/bin/etcd \\
      #{ssl_args}
      --name=#{node['fqdn']} \\
      --data-dir=${data_dir} \\
      --advertise-client-urls=#{etcd_scheme}://#{node['service_ip']}:2379 \\
      --listen-client-urls=#{etcd_scheme}://#{node['service_ip']}:2379,#{etcd_scheme}://127.0.0.1:2379 \\
      --listen-peer-urls=#{etcd_scheme}://#{node['service_ip']}:2380 \\
      --initial-advertise-peer-urls=#{etcd_scheme}://#{node['service_ip']}:2380 \\
      --initial-cluster-token=#{node['bcpc']['cloud']['region']}-etcd-cluster-01 \\
      --initial-cluster=#{initial_cluster} \\
      --initial-cluster-state=#{initial_cluster_state}

    [Install]
    WantedBy=multi-user.target
  DOC
end

execute 'wait for etcd membership' do
  environment etcdctl_env
  retries 5
  command "etcdctl member list | grep #{node['fqdn']}"
end
