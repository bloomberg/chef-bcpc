#
# Cookbook Name:: bcpc-health-check
# Recipe:: check-headnode-count
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

raise Chef::Application.fatal!("Chef reports reduced number of headnodes, see /etc/headnodes") if (get_cached_head_node_names - get_head_nodes.map { |x| x['hostname'] }).length > 0

# TODO configure for lazy evaluation
template "/etc/headnodes" do
    source "headnodes.erb"
    variables(:servers => get_head_nodes)
end
