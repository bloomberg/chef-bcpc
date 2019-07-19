# Cookbook:: bcpc
# Recipe:: calico-felix
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

include_recipe 'bcpc::etcd3gw'
include_recipe 'bcpc::calico-apt'

package 'calico-felix'
service 'calico-felix'

# remove example felix cfg file
file '/etc/calico/felix.cfg.example' do
  action :delete
end

etcd_endpoints = ['https://127.0.0.1:2379']

template '/etc/calico/felix.cfg' do
  source 'calico/felix.cfg.erb'
  variables(
    etcd_endpoints: etcd_endpoints.join(',')
  )
  notifies :restart, 'service[calico-felix]', :immediately
end

template '/etc/calico/calicoctl.cfg' do
  source 'calico/calicoctl.cfg.erb'
  variables(
    cert_type: 'client-ro',
    etcd_endpoints: etcd_endpoints.join(',')
  )
end
