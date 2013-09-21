#
# Cookbook Name:: bcpc-centos
# Recipe:: networking
#
# Copyright 2013, Bloomberg L.P.
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

template "/etc/sysconfig/network-scripts/ifcfg-#{node[:bcpc][:management][:interface]}" do
  source "network.ifcfg.erb"
  owner "root"
  group "root"
  mode 00644
  variables(
    :interface => node[:bcpc][:management][:interface],
    :ip => node[:bcpc][:management][:ip],
    :netmask => node[:bcpc][:management][:netmask],
    :gateway => node[:bcpc][:management][:gateway],
    :dns => node[:bcpc][:management][:dns]
  )
end

template "/etc/sysconfig/network-scripts/ifcfg-#{node[:bcpc][:storage][:interface]}" do
  source "network.ifcfg.erb"
  owner "root"
  group "root"
  mode 00644
  variables(:interface => node[:bcpc][:storage][:interface])
end

template "/etc/sysconfig/network-scripts/ifcfg-#{node[:bcpc][:storage][:vlan_interface]}" do
  source "network.ifcfg.vlan.erb"
  owner "root"
  group "root"
  mode 00644
  variables(
    :interface => node[:bcpc][:storage][:vlan_interface],
    :ip => node[:bcpc][:storage][:ip],
    :netmask => node[:bcpc][:storage][:netmask],
    :gateway => node[:bcpc][:storage][:gateway]
  )
end

template "/etc/sysconfig/network-scripts/ifcfg-#{node[:bcpc][:floating][:interface]}" do
  source "network.ifcfg.erb"
  owner "root"
  group "root"
  mode 00644
  variables(:interface => node[:bcpc][:floating][:interface])
end

template "/etc/sysconfig/network-scripts/ifcfg-#{node[:bcpc][:floating][:vlan_interface]}" do
  source "network.ifcfg.vlan.erb"
  owner "root"
  group "root"
  mode 00644
  variables(
    :interface => node[:bcpc][:floating][:vlan_interface],
    :ip => node[:bcpc][:floating][:ip],
    :netmask => node[:bcpc][:floating][:netmask],
    :gateway => node[:bcpc][:floating][:gateway]
  )
end

template "/etc/sysconfig/network-scripts/route-#{node[:bcpc][:management][:interface]}" do
  source "network.route.mgmt.erb"
  owner "root"
  group "root"
  mode 00644
end

template "/etc/sysconfig/network-scripts/rule-#{node[:bcpc][:management][:interface]}" do
  source "network.rule.mgmt.erb"
  owner "root"
  group "root"
  mode 00644
end

template "/etc/sysconfig/network-scripts/route-#{node[:bcpc][:storage][:vlan_interface]}" do
  source "network.route.storage.erb"
  owner "root"
  group "root"
  mode 00644
end

template "/etc/sysconfig/network-scripts/rule-#{node[:bcpc][:storage][:interface]}" do
  source "network.rule.storage.erb"
  owner "root"
  group "root"
  mode 00644
end

bash "storage vlan up" do
  user "root"
  code <<-EOH
  ifup #{node[:bcpc][:floating][:interface]}
  ifup #{node[:bcpc][:floating][:vlan_interface]}
  EOH
  not_if "if link show | grep #{node[:bcpc][:floating][:interface]}"
end

template "/etc/hosts" do
  source "hosts.erb"
  owner "root"
  group "root"
  mode 00644
  variables( :servers => get_all_nodes )
end

bash "set hostname" do
  user "root"
  code <<-EOH
  /bin/hostname #{node.name.match(/([a-z_-]+)/)[0]}
  EOH
end
