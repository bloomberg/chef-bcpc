#
# Cookbook Name:: bcpc
# Recipe:: cobbler
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

include_recipe "bcpc::default"

# for mkpasswd
package "whois"

ruby_block "initialize-cobbler-config" do
    block do
        make_config('cobbler-web-user', "cobbler")
        make_config('cobbler-web-password', secure_password)
        make_config('cobbler-web-password-digest', %x[ printf "#{get_config('cobbler-web-user')}:Cobbler:#{get_config('cobbler-web-password')}" | md5sum | awk '{print $1}' ])
        make_config('cobbler-root-password', secure_password)
        make_config('cobbler-root-password-salted', %x[ printf "#{get_config('cobbler-root-password')}" | mkpasswd -s -m sha-512 ])
    end
end

package "isc-dhcp-server"
package "cobbler"
package "cobbler-web"
package 'pxelinux'

service "cobbler"

bash 'disable-mod-python' do
  code 'a2dismod python'
end

systemd_unit 'apache2.service' do
  action [:enable, :start]
end

bash 'disable-mod-python' do
  code 'a2dismod python'
end

cookbook_file '/etc/init.d/cobbler' do
  source 'cobbler/cobbler.init.d'
  notifies :enable, 'service[cobbler]', :immediately
  notifies :restart, 'service[cobbler]', :immediately
end

# for pxelinux.0
# https://bugs.launchpad.net/ubuntu/+source/cobbler/+bug/1570915
link '/usr/lib/syslinux/pxelinux.0' do
  to '/usr/lib/PXELINUX/pxelinux.0'
  link_type 'hard'
end

link '/usr/lib/syslinux/chain.c32' do
  to '/usr/lib/syslinux/modules/efi64/chain.c32'
  link_type 'hard'
end

link '/usr/lib/syslinux/menu.c32' do
  to '/usr/lib/syslinux/modules/efi64/menu.c32'
  link_type 'hard'
end

link '/usr/lib/syslinux/ldlinux.c32' do
  to '/usr/lib/syslinux/modules/bios/ldlinux.c32'
  link_type 'hard'
end

bash 'create-syslinux-hard-links-for-tftp' do
  user 'root'
  code <<-EOH
    cd /var/lib/tftpboot
    for file in `ls -1 /usr/lib/syslinux/modules/bios | grep c32`; do
      ln -fP /usr/lib/syslinux/modules/bios/$file $file;
    done
  EOH
end

cookbook_file "/var/lib/cobbler/distro_signatures.json" do
  source "cobbler/distro_signatures.json"
  notifies :restart, "service[cobbler]", :immediately
end

template "/etc/cobbler/settings" do
  source "cobbler.settings.erb"
  mode 00644
  notifies :restart, "service[cobbler]", :immediately
end

template "/etc/cobbler/users.digest" do
  source "cobbler.users.digest.erb"
  mode 00600
end

# begin generate management networks for all pods for PXE booting
networks = []
management_net = node['bcpc']['management']
management_net.keys.each do |rack|
  next unless rack.start_with?('rack')
  management_net[rack].keys.each do |pod|
    network = {
      'subnet' => management_net[rack][pod]['cidr'].split('/')[0],
      'netmask' => management_net[rack][pod]['netmask'],
      'gateway' => management_net[rack][pod]['gateway']
    }
    networks.push(network)
  end
end

template '/etc/cobbler/dhcp.template' do
  source 'cobbler.dhcp.template.erb'
  mode 00644
  variables(
    'networks' => networks
  )
  notifies :restart, 'service[cobbler]', :immediately
  notifies :run, 'bash[run-cobbler-sync]', :immediately
end
# end generate management subnets

# Ensure first hard disk is used for local boot
template '/etc/cobbler/pxe/pxelocal.template' do
  source 'cobbler.pxelocal.template.erb'
  mode 00644
  owner 'root'
  group 'root'
  notifies :run, 'bash[run-cobbler-sync]', :immediately
end

node['bcpc']['cobbler']['kickstarts'].each do |kickstart|
  template "/var/lib/cobbler/kickstarts/#{kickstart}" do
    source "cobbler.#{kickstart}.erb"
    mode 00644
    variables(
      lazy {
        {
          :bootstrap_node => get_bootstrap_node
        }
      }
    )
  end
end

node['bcpc']['cobbler']['distributions'].each do |distro, distro_attrs|
  iso_path = ::File.join(
    Chef::Config['file_cache_path'], "#{distro}.iso")

  # add thing here to figure out whether to source from cookbook or web URI
  if distro_attrs['iso_source'] == 'bcpc-binary-files'
    cookbook_file iso_path do
      source   distro_attrs['source']
      cookbook 'bcpc-binary-files'
      owner    'root'
      group    'root'
      mode     00444
    end
  elsif distro_attrs['iso_source'] == 'uri'
    remote_file iso_path do
      source   distro_attrs['source']
      checksum distro_attrs['shasum']
      owner    'root'
      group    'root'
      mode     00444
    end
  else
    raise "#{distro_attrs['iso_source']} is not an acceptable ISO source, "
          "must be either 'bcpc-binary-files' or 'uri'"
  end

  bash "import-cobbler-distribution-#{distro}" do
    user "root"
    code <<-EOH
      mount -o loop -o ro #{iso_path} /mnt
      cobbler import --name=#{distro} --path=/mnt \
        --breed=#{distro_attrs['breed']} \
        --os-version=#{distro_attrs['os_version']} \
        --arch=#{distro_attrs['arch']}
      umount /mnt
    EOH
    not_if "cobbler distro list | awk '{ print $1 }' | grep '^#{distro}-#{distro_attrs['arch']}$'"
    notifies :run, "bash[run-cobbler-sync]", :immediately
  end
end

node['bcpc']['cobbler']['profiles'].each do |profile, profile_attrs|
  bash "import-bcpc-cobbler-profile-#{profile}" do
    user "root"
    code <<-EOH
      cobbler profile add --name=#{profile} \
      --distro=#{profile_attrs['distro']} \
      --kickstart=/var/lib/cobbler/kickstarts/#{profile_attrs['kickstart']} \
      --kopts="interface=auto"
    EOH
    not_if "cobbler profile list | awk '{ print $1 }' | grep '^#{profile}$'"
    notifies :run, "bash[run-cobbler-sync]", :immediately
  end
end

template '/etc/default/tftpd-hpa' do
  source 'etc_default_tftpd-hpa.erb'
  mode 00644
  variables(
    :address => node['bcpc']['tftpd']['address']
  )
  notifies :restart, 'service[tftpd-hpa]', :delayed
end

service "isc-dhcp-server" do
    action [:enable, :start]
end

bash "run-cobbler-sync" do
  code "cobbler sync"
  action :nothing
end

service 'tftpd-hpa' do
  action [:enable, :start]
end
