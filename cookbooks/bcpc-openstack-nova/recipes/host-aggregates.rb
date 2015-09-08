#
# Cookbook Name:: bcpc-openstack-nova
# Recipe:: host-aggregates
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

parsed_rack_number = node['bcpc']['rack_name'].match(/^rack-(\d+)/)
az_number = parsed_rack_number.nil? ? 1 : parsed_rack_number.captures[0].to_i
availability_zone = (node['bcpc']['availability_zone'].nil? ) ? node['bcpc']['region_name'] + "-" + az_number.to_s : node['bcpc']['availability_zone'].to_s

node['bcpc']['host_aggregates'].each do |name, properties|
  bcpc_openstack_nova_host_aggregate name do
    metadata properties
  end
end

node['bcpc']['aggregate_membership'].each do |name| 
    bcpc_openstack_nova_host_aggregate name do
        action :member 
    end
end 

bcpc_openstack_nova_host_aggregate availability_zone do
  action :create
  zone availability_zone
end

bcpc_openstack_nova_host_aggregate availability_zone do
  action :member
end

node['bcpc']['aggregate_membership'].each do |name|
    bcpc_openstack_nova_host_aggregate name do
        action :member
        zone  node['bcpc']['region_name']
    end
end
