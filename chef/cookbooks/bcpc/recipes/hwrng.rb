#
# Cookbook Name:: bcpc
# Recipe:: hwrng
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

return unless node['bcpc']['hwrng']['enabled']

package "rng-tools"
service "rng-tools"

execute 'load rng kernel module' do
  command 'modprobe tpm_rng'
  not_if "lsmod | grep -q tpm_rng"
end

execute "load rng kernel module on boot" do
  command <<-EOH
    echo 'tpm_rng' >> /etc/modules
  EOH
  not_if "grep -w tpm_rng /etc/modules"
end

template "/etc/default/rng-tools" do
  source 'hwrng/rng-tools.erb'
  mode   '00644'
  variables(
    rng_source: node['bcpc']['hwrng']['source']
  )
end

package "rng-tools" do
  action :install
end

service "rng-tools" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/default/rng-tools]", :delayed
end
