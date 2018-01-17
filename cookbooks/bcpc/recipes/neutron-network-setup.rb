#
# Cookbook Name:: bcpc
# Recipe:: neutron-network-setup
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

# recipe is only pertinent to Neutron
return unless node['bcpc']['enabled']['neutron']

# spin until Neutron starts to respond, avoids blowing up on an HTTP 503
bash "wait-for-neutron-to-become-operational" do
  code ". /root/openrc-neutron; until neutron net-list >/dev/null 2>&1; do sleep 1; done"
  timeout 30
end

bash "configure-neutron-fixed-network" do
  code ". /root/openrc-neutron; neutron net-create --shared --provider:network_type local #{node['bcpc']['calico']['fixed_network']['name']}"
  not_if ". /root/openrc-neutron; neutron net-show #{node['bcpc']['calico']['fixed_network']['name']}"
end

bash "configure-neutron-fixed-subnet" do
  code ". /root/openrc-neutron; neutron subnet-create --name #{node['bcpc']['calico']['fixed_network']['subnet']} #{node['bcpc']['calico']['fixed_network']['name']} #{node['bcpc']['calico']['fixed_network']['subnet']}"
  not_if ". /root/openrc-neutron; neutron subnet-show #{node['bcpc']['calico']['fixed_network']['subnet']}"
end
