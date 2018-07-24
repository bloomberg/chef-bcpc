# Cookbook Name:: bcpc
# Recipe:: bird
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

apt_repository 'bird' do
  uri node['bcpc']['bird']['repo']['url']
  distribution node['lsb']['codename']
  components ['main']
  key 'bird/release.key'
  only_if { node['bcpc']['bird']['repo']['enabled'] }
end

package "bird" do
  action :install
end

service 'bird'

service 'bird6' do
  action %i[disable stop]
end

begin
  rack = node_rack
  iface = node_interfaces.find { |i| i['type'] == 'primary' }

  raise "no rack found with an ID #{rack_id} and POD #{pod_id}" if rack.nil?

  template '/etc/bird/bird.conf' do
    source 'bird/bird.conf.erb'

    variables(
      is_worknode: worknode?(node),
      is_headnode: headnode?(node),
      as_number: rack['bgp_as'],
      iface: iface['dev'],
      upstream_peer: rack['networks']['primary']['gateway']
    )

    notifies :restart, 'service[bird]', :immediately
  end
end
