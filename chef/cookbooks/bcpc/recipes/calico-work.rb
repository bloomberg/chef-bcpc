# Cookbook Name:: bcpc
# Recipe:: calico-work
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

include_recipe 'bcpc::calico-apt'

%w(
  calico-common
  calico-compute
  calico-dhcp-agent
  calico-felix
).each do |pkg|
  package pkg do
    action :upgrade
  end
end

directory '/etc/calico'

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'
  variables(
    nodes: ['http://localhost:2379']
  )
end

# these neutron services are installed/enabled by calico packages
# these services are superseded by nova-metadata-agent and calico-dhcp-agent
# so we don't need them to be enabled/running
service 'neutron-dhcp-agent' do
  action [:disable, :stop]
end

service 'neutron-metadata-agent' do
  action [:disable, :stop]
end

service 'calico-felix'
service 'calico-dhcp-agent'

template '/etc/neutron/neutron.conf' do
  source 'calico/neutron.conf.erb'
  mode '644'
  owner 'root'
  group 'neutron'

  variables(
    vip: get_address(node['bcpc']['cloud']['vip']['ip'])
  )

  notifies :restart, 'service[calico-dhcp-agent]', :immediately
end

systemd_unit 'calico-felix.service' do
  action [:create, :enable, :restart]

  content <<-DOC.gsub(/^\s+/, '')
    [Unit]
    Description=Calico Felix agent
    After=syslog.target network.target

    [Service]
    User=root
    Environment=ETCD_ENDPOINTS=http://localhost:2379
    ExecStartPre=/bin/mkdir -p /var/run/calico
    ExecStart=/usr/bin/calico-felix
    KillMode=process
    Restart=on-failure
    LimitNOFILE=32000

    [Install]
    WantedBy=multi-user.target
  DOC
end
