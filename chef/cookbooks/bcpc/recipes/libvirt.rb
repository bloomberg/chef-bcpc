# Cookbook Name:: bcpc
# Recipe:: libvirt
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

=begin
package 'qemu-kvm'
package 'libvirt-bin'

service 'libvirtd'

template "/etc/libvirt/libvirtd.conf" do
  source "libvirtd.conf.erb"
  mode 00644
  notifies :restart, "service[libvirtd]", :immediately
end

template "/etc/default/libvirtd" do
  source "libvirtd-default.erb"
  mode 00644
  notifies :restart, "service[libvirtd]", :immediately
end

cookbook_file "/etc/libvirt/qemu.conf" do
  source "libvirt-qemu.conf"
  mode 00644
  notifies :restart, "service[libvirtd]", :immediately
end

execute "create cinder keyring" do
  cwd '/etc/ceph'
  command "ceph auth get-or-create client.cinder > ceph.client.cinder.keyring"
  creates "/etc/ceph/ceph.client.cinder.keyring"
end

file '/etc/ceph/ceph.client.cinder.keyring' do
  owner 'root'
  group 'ceph'
end

template "/root/virsh-secret.xml" do
  source "virsh-secret.xml.erb"
  notifies :run, "bash[load virsh secrets]", :immediately
  not_if "virsh secret-list | grep -i #{get_config('libvirt-secret-uuid')}"
end

bash "load virsh secrets" do
  action :nothing

  code <<-EOH
    virsh secret-define --file /root/virsh-secret.xml
    virsh secret-set-value \
      --secret #{get_config('libvirt-secret-uuid')} \
      --base64 $(ceph auth get-key client.cinder)
  EOH
end

file "/root/virsh-secret.xml" do
  action :delete
end

bash "remove-default-virsh-net" do
  code <<-EOH
      virsh net-destroy default
      virsh net-undefine default
  EOH
  only_if "virsh net-list | grep -i default"
end
=end
