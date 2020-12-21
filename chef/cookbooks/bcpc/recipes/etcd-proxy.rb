# Cookbook:: bcpc
# Recipe:: etcd-proxy
#
# Copyright:: 2020 Bloomberg Finance L.P.
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
include_recipe 'bcpc::etcd-ssl'

# Headnodes have etcd-member and don't need etcd-proxy.
return if headnode?

service 'etcd'

headnodes = headnodes(all: true)

etcd_endpoints = headnodes.collect do |headnode|
  "https://#{headnode['service_ip']}:2379"
end

template '/etc/systemd/system/etcd.service' do
  source 'etcd-proxy/etcd.service.erb'
  variables(
    etcd_endpoints: etcd_endpoints
  )

  notifies :run, 'execute[enable etcd service]', :immediately
  notifies :run, 'execute[reload systemd]', :immediately
  notifies :restart, 'service[etcd]', :immediately
end

execute 'enable etcd service' do
  action :nothing
  command 'systemctl enable etcd.service'
  not_if 'systemctl is-enabled etcd.service'
end

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end

unless bootstrap?
  execute 'wait for etcd membership' do
    environment etcdctl_env
    retries 5
    command 'etcdctl member list'
  end
end
