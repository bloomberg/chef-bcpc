#
# Cookbook Name:: bcpc
# Recipe:: apt
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
template '/etc/apt/apt.conf.d/00bcpc' do
  source 'apt/bcpc-apt.conf.erb'
  variables(
    conf: node['bcpc']['apt']
  )
end

template '/etc/apt/sources.list' do
  source 'apt/sources.list.erb'
  variables(
    config: node['bcpc']['ubuntu']
  )
end

execute 'apt-get update' do
  command 'apt-get update'
end
