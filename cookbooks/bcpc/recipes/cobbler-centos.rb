#
# Cookbook Name:: bcpc
# Recipe:: cobbler-centos
#
# Copyright 2013, Bloomberg Finance L.P.
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

include_recipe "bcpc::cobbler"

template "/var/lib/cobbler/kickstarts/bcpc_centos_host.preseed" do
    source "cobbler.bcpc_centos_host.preseed.erb"
    mode 00644
end

remote_file "/tmp/centos-6-initrd.img" do
    source "#{get_binary_server_url}/centos-6-initrd.img"
    owner "root"
    mode 00444
end

remote_file "/tmp/centos-6-vmlinuz" do
    source "#{get_binary_server_url}/centos-6-vmlinuz"
    owner "root"
    mode 00444
end

bash "import-centos-distribution-cobbler" do
    user "root"
    code <<-EOH
        cobbler distro add --name=centos-6-x86_64 --kernel=/tmp/centos-6-vmlinuz --initrd=/tmp/centos-6-initrd.img --breed=redhat --os-version=rhel6 --arch=x86_64
        cobbler sync
    EOH
    not_if "cobbler distro list | grep centos-6-x86_64"
end

bash "import-centos-profile-cobbler" do
    user "root"
    code <<-EOH
        cobbler profile add --name=bcpc_centos --distro=centos-6-x86_64 --kickstart=/var/lib/cobbler/kickstarts/bcpc_centos_host.preseed --kopts="priority=critical locale=en_US netcfg/choose_interface=auto"
        cobbler sync
    EOH
    not_if "cobbler profile list | grep bcpc_centos"
end
