#
# Cookbook Name:: bcpc-consul
# Recipe:: watches
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

definition = {}
definition['watches'] = node['bcpc-consul']['watches']

definition['watches'].each do |watch|
  script_name = watch['args'][0].split('/')[-1]
  template watch['args'][0] do
    source "#{script_name}.erb"
    owner 'root'
    group 'root'
    mode 00755
  end
end

template "#{node['bcpc-consul']['conf_dir']}/watches.json" do
  source 'config.json.erb'
  owner node['bcpc-consul']['username']
  group 'root'
  mode 00644
  variables(
    'config' => JSON.pretty_generate(definition)
  )
  notifies :reload, 'service[consul]', :immediate
end
