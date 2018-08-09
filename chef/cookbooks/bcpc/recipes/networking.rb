# Cookbook Name:: bcpc
# Recipe:: networking
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

vip = node['bcpc']['cloud']['vip']

service 'systemd-resolved'

cookbook_file '/etc/modules-load.d/8021q.conf' do
  source 'modules-load.d/8021q.conf'
end

execute 'load 8021q kernel module' do
  command 'modprobe 8021q'
  not_if 'lsmod | grep ^8021q'
end

template '/etc/hosts' do
  source 'etc/hosts.erb'
  variables(
    vip: vip['ip'],
    nodes: all_nodes
  )
end

# primary interface configuration
#
begin
  primary = node_interfaces(type: 'primary')
  raise 'unable to find the primary interface' if primary.nil?

  data = {
    'network' => {
      'version' => 2,
      'ethernets' => {
        primary['dev'] => {
          'addresses' => [
            "#{primary['ip']}/#{primary['prefix']}",
          ],
          'gateway4' => primary['gw'],
          'nameservers' => {
            'addresses' => [vip['ip'], node['bcpc']['dns_servers']].flatten,
          },
        },
      },
    },
  }

  if primary.key?('mtu')
    mtu = primary['mtu']
    data['network']['ethernets'][primary['dev']]['mtu'] = mtu
  end

  file "/etc/netplan/#{primary['dev']}.yaml" do
    content data.to_yaml(Indent: 2).to_s
  end
end

# storage interface configuration
#
begin
  storage = node_interfaces(type: 'storage')
  raise 'unable to find the storage interface' if storage.nil?

  data = {
    'network' => {
      'version' => 2,
      'ethernets' => {
        storage['dev'] => {
          'addresses' => [
            "#{storage['ip']}/#{storage['prefix']}",
          ],
          'routes' => [
            {
              'to' => storage['route']['to'],
              'via' => storage['route']['via'],
            },
          ],
        },
      },
    },
  }

  if storage.key?('mtu')
    mtu = storage['mtu']
    data['network']['ethernets'][storage['dev']]['mtu'] = mtu
  end

  if storage.key?('vlan')
    vlan = storage['vlan']

    data['network']['vlans'] = {
      "vlan#{vlan}" => {
        'id' => vlan,
        'link' => storage['dev'],
        'addresses' => [
          "#{storage['ip']}/#{storage['prefix']}",
        ],
      },
    }

    data['network']['ethernets'][storage['dev']].delete('addresses')
  end

  file "/etc/netplan/#{storage['dev']}.yaml" do
    content data.to_yaml(Indent: 2).to_s
  end
end

if headnode?

  data = {
    'network' => {
      'version' => 2,
      'ethernets' => {
        'lo' => {
          'addresses' => ['127.0.0.1/8', "#{vip['ip']}/#{vip['prefix']}"],
        },
      },
    },
  }

  file '/etc/netplan/lo.yaml' do
    content data.to_yaml(Indent: 2).to_s
  end
end

execute 'netplan apply' do
  command 'netplan apply'
end

# update /etc/resolv.conf to point to the real resolv.conf to avoid using
# systemds internal dns resolver
link '/etc/resolv.conf' do
  to '/run/systemd/resolve/resolv.conf'
  notifies :restart, 'service[systemd-resolved]', :immediately
end
