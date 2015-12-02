#
# Cookbook Name:: bcpc-openstack-ceilometer
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

include_recipe "bcpc-openstack-common"

ruby_block "initialize-ceilometer-config" do
    block do
        make_config('mysql-ceilometer-user', "ceilometer")
        make_config('mysql-ceilometer-password', secure_password)
        make_config('ceilometer-secret', secure_password)
    end
end

package "ceilometer-common"

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    owner "ceilometer"
    group "ceilometer"
    mode 00600
    variables(
      lazy {
        {:servers => get_head_nodes}
      }
    )
end
