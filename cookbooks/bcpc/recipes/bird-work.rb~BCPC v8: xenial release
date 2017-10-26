#
# Cookbook Name:: bcpc
# Recipe:: bird-compute
#
# Copyright 2017, Bloomberg Finance L.P.
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
include_recipe 'bcpc::packages-bird'

package 'bird'

service 'bird'

# disable IPv6 for now
service 'bird6' do
  action [:disable, :stop]
end

rack = node['bcpc']['rack_name']
pod = node['bcpc']['pod_name']
template '/etc/bird/bird.conf' do
  source "bird.conf.erb"
  mode 0644

  bgp_as = node['bcpc']['management'][rack][pod]['bgp_as']
  workload_interface = node['bcpc']['calico']['bgp']['workload_interface']
  gateway = node['bcpc']['management'][rack][pod]['gateway']

  variables(
    :as_number => bgp_as,
    :workload_interface => workload_interface,
    :upstream_peer => gateway
  )

  notifies :restart, 'service[bird]', :immediately
end
