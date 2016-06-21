#
# Cookbook Name:: bcpc
# Recipe:: crashkernel
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

# NOTE: installing kdump-tools will require a full system reboot to take
# effect (use the "coldreboot" command to ensure that kdump doesn't try to
# load a new kernel onto the existing one, but reboots from POST and
# enables crashkernel correctly; this can be verified by running
# "kdump-config test" and "kdump-config status")

package "kdump-tools" do
  action :upgrade
end

template "/etc/default/kdump-tools" do
  source "crash-debugging.kdump-tools.erb"
  owner  "root"
  group  "root"
  mode   00644
end

package "linux-crashdump" do
  action :upgrade
end

template "/etc/default/grub.d/kexec-tools.cfg" do
  source "crash-debugging.kexec-tools.cfg.erb"
  owner  "root"
  group  "root"
  mode   00644
  notifies :run, "bash[crash-debugging-update-initramfs]", :immediately
  notifies :run, "bash[crash-debugging-update-grub]", :immediately
end

bash "crash-debugging-update-initramfs" do
  code "update-initramfs -k all -u"
  action :nothing
end

bash "crash-debugging-update-grub" do
  code "update-grub"
  action :nothing
end
