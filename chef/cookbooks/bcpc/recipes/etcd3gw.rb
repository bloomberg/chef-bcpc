# Cookbook:: bcpc
# Recipe:: etcd3gw
#
# Copyright:: 2022 Bloomberg Finance L.P.
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

if platform?('ubuntu') && node['platform_version'] == '18.04'
  package %w(
    python3-futurist
    python3-pbr
    python3-requests
    python3-setuptools
    python3-six
    python3-urllib3
    python3-wheel
  )

  target = node['bcpc']['etcd3gw']['remote_file']['file']
  etcd3gw = File.basename("#{target}", '.tar.gz')
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
      # Bionic version (2.18.4) of python3-requests has addressed CVE-2018-18074
      sed -i.orig '/^requests>=/s/2\.20\.0/2.18.4/' #{etcd3gw}/requirements.txt
      python3 -m pip install ./#{etcd3gw}
    EOH
    retries 5
    retry_delay 2
  end
elsif platform?('ubuntu') && ['20.04', '22.04'].include?(node['platform_version'])
  package 'python3-etcd3gw'
end
