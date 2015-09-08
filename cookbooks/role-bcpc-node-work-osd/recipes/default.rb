#
# Cookbook Name:: role-bcpc-node-work-osd
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# save the node at the start of the run so that its run list is available
node.save
# magic sleep so that Chef server has time to reindex
sleep 2

include_recipe 'component-bcpc-common'
include_recipe 'component-bcpc-node-common'
include_recipe 'component-bcpc-node-work-common'
include_recipe 'bcpc-ceph::write-bootstrap-osd-key'
include_recipe 'bcpc-ceph::write-client-admin-key'
include_recipe 'bcpc-ceph::osd'
include_recipe 'bcpc-ceph::radosgw'
include_recipe 'bcpc-health-check::worknode'
include_recipe 'component-bcpc-node-monitoring'
