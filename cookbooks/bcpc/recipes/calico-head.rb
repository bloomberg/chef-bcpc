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
include_recipe 'bcpc::packages-calico'

%w(calico-control calico-common).each do |pkg|
  package pkg do
    action :upgrade
  end
end

directory '/etc/calico'

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'

  etcd_nodes = get_head_nodes().map{|h|
    "http://#{h['bcpc']['management']['ip']}:2379"
  }

  variables(:etcd_nodes => etcd_nodes)
end

