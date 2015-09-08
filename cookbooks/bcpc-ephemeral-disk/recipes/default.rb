#
# Cookbook Name:: bcpc-ephemeral-disk
# Recipe:: default
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if node['bcpc']['nova']['ephemeral']
  package 'lvm2'

  bash "setup-lvm-pv" do
    user "root"
    code <<-EOH
    pvcreate #{ node['bcpc']['nova']['ephemeral_disks'].join(' ') }
  EOH
    not_if "pvdisplay | grep '/dev'"
  end

  bash "setup-lvm-lv" do
    user "root"
    code <<-EOH
    vgcreate nova_disk  #{ node['bcpc']['nova']['ephemeral_disks'].join(' ') }
  EOH
    not_if "vgdisplay nova_disk"
  end
end
