#
# Cookbook Name:: bcpc-bootstrap
# Recipe:: cobbler
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

# for mkpasswd
package "whois"

ruby_block "initialize-cobbler-config" do
  block do
    make_config('cobbler-web-user', "cobbler")
    make_config('cobbler-web-password', secure_password)
    make_config_from_cmd('cobbler-web-password-digest', "printf \"#{get_config('cobbler-web-user')}:Cobbler:#{get_config('cobbler-web-password')}\" | md5sum | awk '{print $1}'")
    make_config('cobbler-root-password', secure_password)
    make_config_from_cmd('cobbler-root-password-salted', "printf \"#{get_config('cobbler-root-password')}\" | mkpasswd -s -m sha-512")
  end
end

package "isc-dhcp-server"
package "cobbler"
package "cobbler-web"

template "/etc/cobbler/settings" do
    source "cobbler.settings.erb"
    mode 00644
    notifies :restart, "service[cobbler]", :delayed
end

template "/etc/cobbler/users.digest" do
    source "cobbler.users.digest.erb"
    mode 00600
end

template "/etc/cobbler/dhcp.template" do
    source "cobbler.dhcp.template.erb"
    mode 00644
    variables(
        :range => node['bcpc']['bootstrap']['dhcp_range'],
        :subnet => node['bcpc']['bootstrap']['dhcp_subnet']
    )
    notifies :restart, "service[cobbler]", :delayed
    notifies :run, "bash[run-cobbler-sync]", :immediately
end

directory "/var/www/cobbler/pub/scripts" do
    action :create
    owner "root"
    group "adm"
    mode 02775
end

cookbook_file "/var/www/cobbler/pub/scripts/get-ssh-keys" do
    source "get-ssh-keys"
    owner "root"
    group "root"
    mode 00755
end

template "/var/lib/cobbler/kickstarts/bcpc_ubuntu_host.preseed" do
    source "cobbler.bcpc_ubuntu_host.preseed.erb"
    mode 00644
    variables(
      lazy {
        {:bootstrap_node => get_bootstrap_node}
      }
    )
end

cookbook_file "/tmp/ubuntu-14.04-mini.iso" do
    source "ubuntu-14.04-mini.iso"
    cookbook "bcpc-binary-files"
    owner "root"
    mode 00444
end

bash "import-ubuntu-distribution-cobbler" do
    user "root"
    code <<-EOH
        mount -o loop -o ro /tmp/ubuntu-14.04-mini.iso /mnt
        cobbler import --name=ubuntu-14.04-mini --path=/mnt --breed=ubuntu --os-version=trusty --arch=x86_64
        umount /mnt
    EOH
    not_if "cobbler distro list | grep ubuntu-14.04-mini"
    notifies :run, "bash[run-cobbler-sync]", :immediately
end

bash "import-bcpc-profile-cobbler" do
    user "root"
    code <<-EOH
        cobbler profile add --name=bcpc_host --distro=ubuntu-14.04-mini-x86_64 --kickstart=/var/lib/cobbler/kickstarts/bcpc_ubuntu_host.preseed --kopts="interface=auto"
    EOH
    not_if "cobbler profile list | grep bcpc_host"
    notifies :run, "bash[run-cobbler-sync]", :immediately
end

service "isc-dhcp-server" do
    action [:enable, :start]
end

service "cobbler" do
    action [:enable, :start]
end

bash "run-cobbler-sync" do
  code "cobbler sync"
  action :nothing
end
