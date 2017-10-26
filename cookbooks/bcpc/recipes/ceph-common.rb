#
# Cookbook Name:: bcpc
# Recipe:: ceph-common
#
# Copyright 2015, Bloomberg Finance L.P.
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

if platform?("debian", "ubuntu")
    include_recipe "bcpc::networking"
end

template '/etc/ceph/ceph.conf' do
    source 'ceph.conf.erb'
    owner 'ceph'
    group 'ceph'
    mode '0644'
    variables(
      lazy {
        {
          :servers => get_ceph_mon_nodes
        }
      }
    )
end

# Intentionally does not trigger restart/reload of Ceph daemons. This is left
# to operator to manage.
template '/etc/default/ceph' do
  source 'ceph-default.erb'
  owner 'root'
  group 'root'
  mode 0644
end

directory '/var/run/ceph/' do
  owner 'ceph'
  group 'ceph'
  mode  '0755'
end

# Script looks for mdsmap and if MDS is removed later then this script will need to be changed.
bash "wait-for-pgs-creating" do
    action :nothing
    user "root"
    code "sleep 1; while ceph -s | grep -v mdsmap | grep creating >/dev/null 2>&1; do echo Waiting for new pgs to create...; sleep 1; done"
end
