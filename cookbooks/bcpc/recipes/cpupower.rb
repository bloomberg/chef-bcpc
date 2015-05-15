
# Cookbook Name:: bcpc
# Recipe:: cpupower
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

# CPU frequency governor utils
template "/etc/default/cpufrequtils" do
  source "cpufrequtils.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[cpufrequtils]", :delayed
end

package "cpufrequtils"

# this service conflicts with the bcpc_cpupower provider, so ensure it is off
service "cpufrequtils" do
  action [:disable, :stop]
end

bcpc_cpupower "cpu governor" do
  governor                      node['bcpc']['cpupower']['governor']
  ondemand_ignore_nice_load     node['bcpc']['cpupower']['ondemand_ignore_nice_load']
  ondemand_io_is_busy           node['bcpc']['cpupower']['ondemand_io_is_busy']
  ondemand_powersave_bias       node['bcpc']['cpupower']['ondemand_powersave_bias']
  ondemand_sampling_down_factor node['bcpc']['cpupower']['ondemand_sampling_down_factor']
  ondemand_sampling_rate        node['bcpc']['cpupower']['ondemand_sampling_rate']
  ondemand_up_threshold         node['bcpc']['cpupower']['ondemand_up_threshold']
end
