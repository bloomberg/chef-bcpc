#
# Cookbook Name:: bcpc-consul
# Recipe:: services
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

services = node['bcpc-consul']['services']
definition = {}
if services.length == 1
  definition['service'] = services[0]
elsif services.length > 1
  definition['services'] = services
end

services.each do |sv|
  script = sv['check']['args'].dup
  script[0].include?('sudo') ? script = script[1] : script = script[0]
  script_name = (script.split('/'))[-1]
  cookbook_file script do
    source script_name
    owner 'root'
    group 'root'
    mode 00755
  end
end

template "#{node['bcpc-consul']['conf_dir']}/services.json" do
  source 'config.json.erb'
  owner node['bcpc-consul']['username']
  group 'root'
  mode 00644
  variables(
    'config' => JSON.pretty_generate(definition)
  )
  notifies :restart, 'service[consul]', :delayed
end
