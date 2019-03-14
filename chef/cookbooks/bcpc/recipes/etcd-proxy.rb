# Cookbook Name:: bcpc
# Recipe:: etcd-proxy
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

headnodes = headnodes(all: true)
etcd_scheme = node['bcpc']['etcd']['scheme']
etcd_port = node['bcpc']['etcd']['client']['port']
etcd_listen_host = node['bcpc']['etcd']['proxy']['listen']['host']
etcd_listen_port = node['bcpc']['etcd']['proxy']['listen']['port']

etcd_endpoints = headnodes.collect do |headnode|
  "#{etcd_scheme}://#{headnode['service_ip']}:#{etcd_port}"
end

listen_addr = "#{etcd_listen_host}:#{etcd_listen_port}"

systemd_unit 'etcd.service' do
  action %i(create enable restart)
  content <<-DOC.gsub(/^\s+/, '')
    [Unit]
    Description=etcd
    Documentation=https://github.com/coreos/etcd

    [Service]
    Type=notify
    Restart=always
    RestartSec=5s
    LimitNOFILE=40000
    TimeoutStartSec=0

    ExecStart=/usr/local/bin/etcd gateway start \\
      --endpoints=#{etcd_endpoints.join(',')} \\
      --listen-addr=#{listen_addr}

    [Install]
    WantedBy=multi-user.target
  DOC
end
