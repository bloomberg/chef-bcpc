#
# Cookbook Name:: bcpc
# Recipe:: ceph_mgr
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

ceph_mgr_dir = "/var/lib/ceph/mgr/ceph-#{node['hostname']}"

directory ceph_mgr_dir do
  owner 'ceph'
  group 'ceph'
end

bash 'initialize-ceph-mgr-keyring' do
  user 'ceph'
  code <<-EOH
    ceph auth get-or-create mgr.#{node['hostname']} \
      mon 'allow profile mgr' \
      osd 'allow *' > #{ceph_mgr_dir}/keyring
  EOH
  not_if "test -f #{ceph_mgr_dir}/keyring"
end

service "ceph-mgr@#{node['hostname']}" do
  action %w[enable start]
end
