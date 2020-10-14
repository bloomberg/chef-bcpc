# Cookbook:: bcpc
# Recipe:: lvm2
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

package 'lvm2'
service 'lvm2-monitor' do
  action [:enable, :start]
end

directory '/etc/systemd/system/lvm2-monitor.service.d' do
  action :create
end

cookbook_file '/etc/systemd/system/lvm2-monitor.service.d/custom.conf' do
  source 'lvm2/custom.conf'
  notifies :run, 'execute[reload systemd]', :immediately
end

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end
