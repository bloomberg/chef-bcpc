#
# Cookbook Name:: bcpc
# Recipe:: nova-setup
#
# Copyright 2013, Bloomberg L.P.
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

include_recipe "bcpc::keystone"
include_recipe "bcpc::nova-head"
include_recipe "bcpc::nova-work"

cookbook_file "/root/logwatch.sh" do
    source "logwatch.sh"
    owner "root"
    mode 00755
end

cookbook_file "/tmp/cirros-0.3.0-x86_64-disk.img" do
    source "bins/cirros-0.3.0-x86_64-disk.img"
    owner "root"
    mode 00444
end

bash "glance-cirros-image" do
    user "root"
    code <<-EOH
        . /root/adminrc
        qemu-img convert -f qcow2 -O raw /tmp/cirros-0.3.0-x86_64-disk.img /tmp/cirros-0.3.0-x86_64-disk.raw
        glance image-create --name='Cirros 0.3.0 x86_64' --is-public=True --container-format=bare --disk-format=raw --file /tmp/cirros-0.3.0-x86_64-disk.raw
    EOH
    not_if ". /root/adminrc; glance image-list | grep Cirros"
end
