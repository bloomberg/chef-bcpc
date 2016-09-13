#
# Cookbook Name:: bcpc_common
# Recipe:: apt_upgrade
#
# Copyright 2016, Bloomberg Finance L.P.
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

include_recipe 'apt'

bash 'perform-dist-upgrade' do
  user 'root'
  code <<-EOH
    DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" dist-upgrade
  EOH
  only_if { node['bcpc']['enabled']['apt_dist_upgrade'] }
end

bash 'perform-upgrade' do
  user 'root'
  code <<-EOH
    DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" upgrade
  EOH
  only_if { node['bcpc']['enabled']['apt_upgrade'] }
end
