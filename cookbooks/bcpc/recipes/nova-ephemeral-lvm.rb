#
# Cookbook Name:: bcpc
# Recipe:: nova-ephemeral-lvm
#
# Copyright 2015, Bloomberg Finance L.P.
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

# This recipe should be ran after nova-ephemeral has run

package lvm2 do
  action :upgrade
end

# Devices must match and be available
device_list = []

node['bcpc']['nova']['ssd_disks'].each do |disk|
  device_list.push("/dev/#{disk}")
end

devices = device_list.join(' ')

bash "setup-lvm-pv" do
  user "root"
  code <<-EOH
    pvcreate #{devices}
  EOH
  not_if "pvdisplay | grep '/dev'"
end

bash "setup-lvm-vg" do
  user "root"
  code <<-EOH
    vgcreate #{node['bcpc']['nova']['volgroup']} #{devices}
  EOH
  not_if "vgdisplay | grep '#{node['bcpc']['nova']['volgroup']}'"
end

bash "setup-lvm-lv" do
  user "root"
  code <<-EOH
    lvcreate -n #{node['bcpc']['nova']['loggroup']} -l 100%FREE #{node['bcpc']['nova']['volgroup']}
  EOH
  not_if "lvdisplay | grep '#{node['bcpc']['nova']['loggroup']}'"
end

bash "mkfs-xfs" do
  user "root"
  code <<-EOH
    mkfs.xfs /dev/mapper/#{node['bcpc']['nova']['volgroup']}/#{node['bcpc']['nova']['loggroup']}
  EOH
  not_if "df | grep '/var/lib/nova/instances'"
end

mount "/var/lib/nova/instances" do
  device "#{node['bcpc']['nova']['volgroup']}/#{node['bcpc']['nova']['loggroup']}"
  fstype "xfs"
  action[:mount, :enable]
  not_if mounted
end

execute "set-permissions" do
  command "chown -R nova:nova /var/lib/nova/instances"
  user "root"
end
