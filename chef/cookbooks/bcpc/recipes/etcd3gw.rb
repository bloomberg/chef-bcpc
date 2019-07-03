# Cookbook:: bcpc
# Recipe:: etcd3gw
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

package 'python-futurist'

target = node['bcpc']['etcd3gw']['remote_file']['file']
save_path = "#{Chef::Config[:file_cache_path]}/#{target}"
web_server_url = node['bcpc']['web_server']['url']

remote_file save_path do
  source "#{web_server_url}/#{target}"
  checksum node['bcpc']['etcd3gw']['remote_file']['checksum']
  notifies :run, 'bash[install etcd3gw]', :immediately
end

bash 'install etcd3gw' do
  action :nothing
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar -xzf #{target}
    pip install $(basename #{target} .tar.gz)/
  EOH
end
