#
# Cookbook Name:: bcpc
# Recipe:: calico-head
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
include_recipe 'bcpc::calico-apt'

%w(calico-control calico-common).each do |pkg|
  package pkg do
    action :install
    notifies :restart, 'service[neutron-server]', :delayed
  end
end

directory '/etc/calico'

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'

  headnodes = get_headnodes(all:true)

  variables(
    :nodes => headnodes.map{|h| "http://#{h['ipaddress']}:2379"}.join(',')
  )
end

