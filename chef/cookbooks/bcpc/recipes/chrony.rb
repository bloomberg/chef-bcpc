# Cookbook:: bcpc
# Recipe:: chrony
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

package 'chrony'
service 'chrony'

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end

directory '/etc/systemd/system/chrony.service.d' do
  action :create
end

# Work-around so that Chrony daemon waits for network to become online.
cookbook_file '/etc/systemd/system/chrony.service.d/custom.conf' do
  source 'chrony/custom.conf'
  notifies :run, 'execute[reload systemd]', :immediately
end

template '/etc/chrony/chrony.conf' do
  source 'chrony/chrony.conf.erb'
  variables(
    servers: node['bcpc']['ntp']['servers']
  )
  notifies :restart, 'service[chrony]', :immediately
end
