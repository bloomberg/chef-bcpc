# Cookbook Name:: bcpc
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

bash "wait-for-aggregates-to-become-operational" do
  code ". /root/adminrc; until openstack aggregate list >/dev/null 2>&1; do sleep 1; done"
  timeout 60
end

# create aggregates
node['bcpc']['host_aggregates'].each do |name, properties|
  bcpc_host_aggregate name do
    metadata properties
  end
end

bcpc_host_aggregate availability_zone do
  zone availability_zone
end

# join/leave compute aggregates and AZ depending on maintenance flag
node['bcpc']['aggregate_membership'].each do |name|
  bcpc_host_aggregate name do
    action join_aggregate_action
  end
end

bcpc_host_aggregate availability_zone do
  action join_aggregate_action
end

# join/leave maintenance aggregate if maintenance flag is se
bcpc_host_aggregate 'maintenance' do
  action maintenance_action
end
