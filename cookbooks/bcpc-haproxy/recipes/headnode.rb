#
# Cookbook Name:: bcpc-haproxy
# Recipe:: headnode
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

include_recipe 'bcpc-haproxy'
include_recipe 'bcpc-xinetd'

# TODO reconfigure for lazy evaluation
template "/etc/haproxy/haproxy.cfg" do
    source "haproxy-head.cfg.erb"
    mode 00644
    variables(
      lazy {
        {
          :servers     => get_head_nodes,
          :all_servers => get_ceph_osd_nodes
        }
      }
    )
    notifies :restart, "service[haproxy]", :immediately
    notifies :restart, "service[xinetd]", :immediately
end
