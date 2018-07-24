#
# Cookbook Name:: bcpc-unbound
# Recipe:: forward
#
# Copyright 2017, Bloomberg Finance L.P.
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

template "#{node['bcpc-unbound']['config_subdir']}/forward.conf" do
  source 'forward.conf.erb'
  owner node['bcpc-unbound']['username']
  group node['bcpc-unbound']['groupname']
  mode 00644
  variables(
    'config' => node['bcpc-unbound']['forward-zone']
  )
  notifies :reload, 'service[unbound]', :immediate
end
