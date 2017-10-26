# Cookbook Name:: bcpc
# Recipe:: etcd-work
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

include_recipe 'bcpc::etcd-packages'

service 'etcd'

template '/etc/systemd/system/etcd.service' do
  source 'etcd/etcd.service.proxy.erb'
  mode   '00644'

  variables('headnodes' => get_head_nodes())

  notifies :run, 'execute[systemctl enable etcd.service]', :immediately
  notifies :run, 'execute[systemctl daemon-reload]', :immediately
  notifies :restart, 'service[etcd]', :immediately
end

execute 'systemctl enable etcd.service' do
  action :nothing
  command 'systemctl enable etcd.service'
  not_if 'systemctl is-enabled etcd.service'
end

execute 'systemctl daemon-reload' do
  action :nothing
  command 'systemctl daemon-reload'
end
