# Cookbook:: bcpc
# Recipe:: hwrng
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

return unless node['bcpc']['hwrng']['enabled']

package 'rng-tools' do
  options '--no-install-recommends'
end

service 'rng-tools'

execute 'load rng kernel module' do
  command 'modprobe tpm_rng'
  not_if 'lsmod | grep -q tpm_rng'
  not_if { ::File.directory?('/sys/module/tpm') }
end

execute 'load rng kernel module on boot' do
  command <<-DOC
    echo 'tpm_rng' >> /etc/modules
  DOC
  not_if 'grep -w tpm_rng /etc/modules'
  not_if { ::File.directory?('/sys/module/tpm') }
end

template '/etc/default/rng-tools' do
  source 'hwrng/rng-tools.erb'
  mode '644'
  variables(
    rng_source: node['bcpc']['hwrng']['source']
  )
  notifies :restart, 'service[rng-tools]', :immediately
end
