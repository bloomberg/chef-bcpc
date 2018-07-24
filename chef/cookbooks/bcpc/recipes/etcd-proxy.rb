# Cookbook Name:: bcpc
# Recipe:: etcd-work
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

include_recipe 'bcpc::etcd-packages'

systemd_unit 'etcd.service' do
  action [:create,:enable,:restart]

  headnodes = get_headnodes(all:true)

  endpoints = headnodes.collect{|h|
    "http://#{h['ipaddress']}:2379"
  }.join(',')

  content <<-EOH.gsub(/^\s+/, '')
    [Unit]
    Description=etcd
    Documentation=https://github.com/coreos/etcd

    [Service]
    Type=notify
    Restart=always
    RestartSec=5s
    LimitNOFILE=40000
    TimeoutStartSec=0

    ExecStart=/usr/local/bin/etcd gateway start \
      --endpoints=#{endpoints} --listen-addr localhost:2379

    [Install]
    WantedBy=multi-user.target
  EOH
end
