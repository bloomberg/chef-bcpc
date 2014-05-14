#
# Cookbook Name:: bcpc
# Recipe:: nova-setup
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

include_recipe "bcpc::keystone"
include_recipe "bcpc::nova-head"

bash "nova-default-secgroup" do
    user "root"
    code <<-EOH
        . /root/adminrc
        nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
        nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    EOH
    not_if ". /root/adminrc; nova secgroup-list-rules default | grep icmp"
end

bash "nova-floating-add" do
    user "root"
    code <<-EOH
        . /root/adminrc
        nova-manage floating create --ip_range=#{node[:bcpc][:floating][:available_subnet]} --pool #{node[:bcpc][:region_name]}
    EOH
    only_if ". /root/adminrc; nova-manage floating list | grep \"No floating IP addresses have been defined\""
end

bash "nova-fixed-add" do
    user "root"
    code <<-EOH
        . /root/adminrc
        nova-manage network create --label fixed --fixed_range_v4=#{node[:bcpc][:fixed][:cidr]} --num_networks=#{node[:bcpc][:fixed][:num_networks]} --multi_host=T --network_size=#{node[:bcpc][:fixed][:network_size]} --vlan=#{node[:bcpc][:fixed][:vlan_start]}
    EOH
    only_if ". /root/adminrc; nova-manage network list | grep \"No networks found\""
end

cookbook_file "/root/logwatch.sh" do
    source "logwatch.sh"
    owner "root"
    mode 00755
end
