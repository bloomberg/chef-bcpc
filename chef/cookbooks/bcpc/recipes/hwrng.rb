#
# Cookbook Name:: bcpc
# Recipe:: hwrng
#
# Copyright 2016, Bloomberg Finance L.P.
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

return unless node['bcpc']['enabled']['hwrng']

bash "ensure-tpm_rng-module-is-loaded" do
  code <<-EOH
    modprobe tpm_rng
  EOH
  not_if "lsmod | grep -q tpm_rng"
end

bash "ensure-tpm_rng-module-loads-on-boot" do
  code <<-EOH
    echo 'tpm_rng' >> /etc/modules
  EOH
  not_if "grep -q tpm_rng /etc/modules"
end

# note that changes to this template do not take effect until reboot
# if rngd is already running
template "/etc/default/rng-tools" do
  source 'rng-tools.erb'
  user   'root'
  group  'root'
  mode   '00644'
  variables(
    rng_source: node['bcpc']['system']['hwrng_source']
  )
end

package "rng-tools" do
  action :install
end

service "rng-tools" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/default/rng-tools]", :delayed
end
