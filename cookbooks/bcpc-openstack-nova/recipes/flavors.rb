# Cookbook Name:: bcpc-openstack-nova
# Recipe:: flavors
#
# Copyright 2013, Bloomberg Finance L.P.
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

node['bcpc']['flavors'].each do |name, flavor|
  bcpc_openstack_nova_osflavor name do
    memory_mb flavor['memory_mb']
    disk_gb   flavor['disk_gb']
    vcpus  flavor['vcpus']
    ephemeral_gb flavor['ephemeral_gb']
    swap_gb flavor['swap_gb']
    is_public flavor['is_public'] or true
    flavor_id flavor['id'] or "auto"
    extra_specs flavor["extra_specs"]
  end
end
