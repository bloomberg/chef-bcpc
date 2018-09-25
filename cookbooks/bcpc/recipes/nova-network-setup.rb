#
# Cookbook Name:: bcpc
# Recipe:: nova-network-setup
#
# Copyright 2013, Bloomberg Finance L.P.
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

# recipe is only pertinent to nova-network
return if node['bcpc']['enabled']['neutron']

include_recipe "bcpc::keystone"
include_recipe "bcpc::nova-head"

# spin until nova starts to respond, avoids blowing up on an HTTP 503
# if Apache was restarted recently and is not yet ready
bash "wait-for-nova-to-become-operational" do
  code ". /root/openrc-nova; until nova secgroup-list >/dev/null 2>&1; do sleep 1; done"
  timeout 30
end

bash "nova-configure-default-icmp-secgroup-rule" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova secgroup-add-default-rule icmp -1 -1 0.0.0.0/0
    EOH
    not_if ". /root/openrc-nova; nova secgroup-list-default-rules | grep icmp"
end

bash "nova-configure-default-ssh-secgroup-rule" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova secgroup-add-default-rule tcp 22 22 0.0.0.0/0
    EOH
    not_if ". /root/openrc-nova; nova secgroup-list-default-rules | grep tcp | grep 22"
end

# AdminTenant will already exist, so the above default rules will not
# have been loaded into that tenancy, so replicate them explicitly
bash "nova-apply-default-icmp-secgroup-rule" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    EOH
    not_if ". /root/openrc-nova; nova secgroup-list-rules default | grep icmp"
end

bash "nova-apply-default-ssh-secgroup-rule" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova secgroup-add-rule default tcp  22 22 0.0.0.0/0
    EOH
    not_if ". /root/openrc-nova; nova secgroup-list-rules default | grep tcp | grep 22"
end

bash "nova-floating-add" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova-manage floating create --ip_range=#{node['bcpc']['floating']['available_subnet']} --pool #{node['bcpc']['region_name']}
    EOH
    only_if ". /root/openrc-nova; nova-manage floating list | grep \"No floating IP addresses have been defined\""
end

node['bcpc'].fetch('additional_floating',[]).each do |float|
  pool = node['bcpc']['region_name']

  float.fetch('ip_pools',[]).each do |ip_pool|
    bash "nova update #{pool} floating ip pool with #{ip_pool}" do
      code <<-EOH
        . /root/openrc-nova
        nova-manage floating create --ip_range=#{ip_pool} --pool #{pool} || true
      EOH
    end
  end
end

bash "nova-fixed-add" do
    user "root"
    code <<-EOH
        . /root/openrc-nova
        nova-manage network create --label fixed --fixed_range_v4=#{node['bcpc']['fixed']['cidr']} --num_networks=#{node['bcpc']['fixed']['num_networks']} --multi_host=T --network_size=#{node['bcpc']['fixed']['network_size']} --vlan_start=#{node['bcpc']['fixed']['vlan_start']} --bridge_interface=#{node['bcpc']['fixed']['vlan_interface']}
    EOH
    only_if ". /root/openrc-nova; nova-manage network list | grep \"No networks found\""
end

node['bcpc'].fetch('additional_fixed',{}).each{ |id,network|
  bash "create #{id} fixed nova network" do
    code <<-EOH
      . /root/adminrc
      nova-manage network create \
        --label #{id} \
        --fixed_range_v4=#{network['cidr']} \
        --num_networks=#{network['num_networks']} \
        --multi_host=T \
        --network_size=#{network['network_size']} \
        --vlan_start=#{network['vlan_start']} \
        --bridge_interface=#{node['bcpc']['fixed']['vlan_interface']}
    EOH
    not_if ". /root/adminrc; nova network-list | awk '{print $4}' | egrep '^#{id}_[0-9]+$'"
  end
}
