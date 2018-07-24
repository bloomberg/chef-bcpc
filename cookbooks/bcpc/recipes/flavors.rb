# Cookbook Name:: bcpc
# Recipe:: flavors
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
#

bash 'wait-for-flavors-to-become-operational' do
  environment os_adminrc
  code 'until openstack flavor list >/dev/null 2>&1; do sleep 1; done'
  timeout 60
end

node['bcpc']['flavors'].each do |name, flavor|
  bcpc_osflavor name do
    memory_mb flavor['memory_mb']
    disk_gb flavor['disk_gb']
    vcpus flavor['vcpus']
    if flavor['ephemeral_gb']
      ephemeral_gb flavor['ephemeral_gb']
    end
    if flavor['swap_gb']
      swap_gb flavor['swap_gb']
    end
    if flavor.key?('is_public')
      is_public flavor['is_public']
    end
    if flavor['id']
      flavor_id flavor['id']
    end
    if flavor['properties']
      properties flavor['properties']
    end
  end
end

# delete default OpenStack flavors (superseded by generic1 class)
%w(m1.tiny m1.small m1.medium m1.large m1.xlarge).each do |flavor|
  bcpc_osflavor flavor do
    action :delete
  end
end
