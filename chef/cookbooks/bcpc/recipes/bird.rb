#
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
#
if node['bcpc']['bird']['repo']['enabled']
  apt_repository "bird" do
    uri node['bcpc']['bird']['repo']['url']
    distribution node['lsb']['codename']
    components ["main"]
    key "bird/release.key"
  end
end

package "bird" do
  action :install
end

service 'bird'

service 'bird6' do
  action [:disable, :stop]
end

template '/etc/bird/bird.conf' do
  source "bird/bird.conf.erb"

  topology = node['bcpc']['networking']['topology']
  racks = topology['racks']
  networks = topology['networks']

  pod_id = node['bcpc']['networking']['pod_id']
  rack_id = node['bcpc']['networking']['rack_id']

  rack = racks.find{ |r|
    r['id'] == rack_id and r['pod'] == pod_id
  }

  if rack.nil?
    raise "no rack found with an ID #{rack_id} and POD #{pod_id}"
  end

  variables(
    :is_worknode => is_worknode(node),
    :is_headnode => is_headnode(node),
    :as_number => rack['bgp_as'],
    :iface => networks['primary']['dev'],
    :upstream_peer => rack['networks']['primary']['gateway']
  )

  notifies :restart, 'service[bird]', :immediately
end
