#
# Cookbook Name:: bcpc-ceph
# Library:: default
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

def power_of_2(number)
  result = 1
  while (result < number) do result <<= 1 end
  result
end

def optimal_pgs_per_node(pool)
  power_of_2(get_ceph_osd_nodes.length * node['bcpc']['ceph']['pgs_per_node'] / node['bcpc']['ceph'][pool]['replicas'] * node['bcpc']['ceph'][pool]['portion'] / 100)
end
