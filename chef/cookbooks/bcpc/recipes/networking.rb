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
#

service 'systemd-resolved'

vip = get_address(node['bcpc']['cloud']['vip']['ip'])

cookbook_file "/etc/modules-load.d/8021q.conf" do
  source 'modules-load.d/8021q.conf'
end

execute 'load 8021q kernel module' do
  command 'modprobe 8021q'
  not_if "lsmod | grep ^8021q"
end

template "/etc/hosts" do
  source "etc/hosts.erb"
  variables(
    :vip => vip,
    :nodes => get_all_nodes()
  )
end

node['bcpc']['networking']['ifaces'].each do |network,spec|

  # primary interface configuration
  #
  if network == 'primary'
    data = {
      "network" => {
        "version" => 2,
        "ethernets" => {
          spec['dev'] => {
            "addresses" => [
              "#{spec['ip']}/#{spec['prefix']}"
            ],
            "gateway4" => spec['gw'],
            "nameservers" => {
              "addresses" => [vip] + node['bcpc']['dns_servers'].dup
            }
          }
        }
      }
    }

    file "/etc/netplan/#{network}.yaml" do
      content "#{data.to_yaml(:Indent => 2)}"
    end
  end

  # storage interface configuration
  #
  if network == 'storage'
    data = {
      "network" => {
        "version" => 2,
        "ethernets" => {
          "#{spec['dev']}" => {
            "addresses" => [
              "#{spec['ip']}/#{spec['prefix']}"
            ],
            "routes" => [
              {
                "to" => "#{spec['route']['to']}",
                "via" => "#{spec['route']['via']}"
              }
            ]
          }
        }
      }
    }

    file "/etc/netplan/#{network}.yaml" do
      content "#{data.to_yaml(:Indent => 2)}"
    end
  end

end

if is_headnode(node)
  anycast = node['bcpc']['networking']['anycast']

  data = {
    "network" => {
      "version" => 2,
      "ethernets" => {
        "lo" => {
          "addresses" => [
            '127.0.0.1/8',
            node['bcpc']['cloud']['vip']['ip']
          ],
        }
      }
    }
  }

  file "/etc/netplan/anycast.yaml" do
    content "#{data.to_yaml(:Indent => 2)}"
  end
end

execute "netplan apply" do
  command "netplan apply"
end

template "/etc/systemd/resolved.conf" do
  source 'systemd/resolved.conf.erb'

  vip = get_address(node['bcpc']['cloud']['vip']['ip'])

  variables(
    :dns => vip,
    :fallback => node['bcpc']['dns_servers'].dup.join(' ')
  )

  notifies :restart, 'service[systemd-resolved]', :immediately
end
