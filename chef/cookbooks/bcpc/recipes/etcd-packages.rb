# Cookbook:: bcpc
# Recipe:: etcd-packages
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

require 'json'

target = node['bcpc']['etcd']['remote']['file']
save_path = "#{Chef::Config[:file_cache_path]}/#{target}"
file_url = node['bcpc']['etcd']['remote']['source']
file_checksum = node['bcpc']['etcd']['remote']['checksum']

remote_file save_path do
  source file_url
  checksum file_checksum
  notifies :run, 'bash[install etcd]', :immediately
end

bash 'install etcd' do
  action :nothing
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar -xf #{target}
    cp $(basename #{target} .tar.gz)/etcd /usr/local/bin/etcd
    cp $(basename #{target} .tar.gz)/etcdctl /usr/local/bin/etcdctl
  EOH
end

bash 'add etcdctl vars to /etc/environment' do
  code <<-EOH
    json='#{etcdctl_env.to_json}'
    keys=$(echo ${json} | jq -r '. | keys | .[]')
    for key in ${keys}; do
      value=$(echo ${json} | jq -r --arg key "${key}" '.[$key]')
      env_variable="${key}=${value}"
      grep -qxF "${env_variable}" /etc/environment \
        || echo "${env_variable}" >> /etc/environment
    done
  EOH
end
