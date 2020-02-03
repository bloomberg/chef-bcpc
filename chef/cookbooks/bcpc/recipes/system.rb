# Cookbook:: bcpc
# Recipe:: system
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

# ipmi module loading and configuration
execute 'load ipmi_devintf kernel module' do
  command 'modprobe ipmi_devintf'
  not_if 'lsmod | grep ipmi_devintf'
end

execute 'load ipmi_devintf kernel module at boot' do
  command 'echo ipmi_devintf >> /etc/modules'
  not_if 'grep ipmi_devintf /etc/modules'
end

# ip_conntrack module loading and configuration
execute 'load ip_conntrack kernel module' do
  command 'modprobe ip_conntrack'
  not_if 'lsmod | grep nf_conntrack'
end

begin
  sys_params = node['bcpc']['system']['parameters']
  nf_conntrack_max = sys_params['net.nf_conntrack_max']
  hashsize = nf_conntrack_max / 8

  template '/etc/modprobe.d/nf_conntrack.conf' do
    source 'modprobe.d/nf_conntrack.conf.erb'
    variables(
      hashsize: hashsize
    )
  end

  execute 'set nf conntrack hashsize' do
    hashsize_fp = '/sys/module/nf_conntrack/parameters/hashsize'
    command "echo #{hashsize} > #{hashsize_fp}"
    not_if "grep -w #{hashsize} #{hashsize_fp}"
  end
end

# configure grub
template '/etc/default/grub' do
  source 'grub/default.erb'

  cmdline = []
  # This addresses the issue with controller vs. disk/device naming issues,
  # providing consistent, deterministic device naming conventions.
  cmdline.push("nvme_core.multipath=0")

  io_scheduler = node['bcpc']['hardware']['io_scheduler']
  cmdline.push("elevator=#{io_scheduler}")

  unless node['bcpc']['grub']['cmdline_linux'].empty?
    cmdline += node['bcpc']['grub']['cmdline_linux']
  end

  variables(
    cmdline: cmdline.join(' ')
  )

  notifies :run, 'execute[update-grub]', :immediately
end

execute 'update-grub' do
  action :nothing
  command 'update-grub2'
end

# sysctl configuration
template '/etc/sysctl.d/70-bcpc.conf' do
  source 'sysctl/bcpc.conf.erb'
  mode '644'

  system = node['bcpc']['system']

  variables(
    parameters: system['parameters'],
    additional_reserved_ports: system['additional_reserved_ports']
  )
  notifies :run, 'execute[reload-sysctl]', :immediately
end

execute 'reload-sysctl' do
  action :nothing
  command 'sysctl -p /etc/sysctl.d/70-bcpc.conf'
end

template '/etc/udev/rules.d/99-readahead.rules' do
  source 'udev/readahead.rules.erb'
  mode '644'
end

# configure I/O scheduler
block_devices = ::Dir.glob('/dev/sd?').map { |d| d.split('/').last }

block_devices.each do |dev|
  io_scheduler = node['bcpc']['hardware']['io_scheduler']

  execute "set #{dev} io-scheduler to #{io_scheduler}" do
    command "echo #{io_scheduler} > /sys/block/#{dev}/queue/scheduler"
    not_if "grep '[#{io_scheduler}]' /sys/block/#{dev}/queue/scheduler"
  end
end

template '/etc/updatedb.conf' do
  source 'updatedb/conf.erb'
  mode '644'
end

# configure system environment profile
cookbook_file '/etc/profile.d/bcpc.sh' do
  source 'profile.d/bcpc.sh'
end

disable_services = %w(iscsid lxcfs lxd rpcbind snapd)
disable_services.each do |svc|
  service svc do
    action [:stop, :disable]
  end
end

motd_packages = %w(
  ubuntu-advantage-tools
  update-notifier-common
  ubuntu-release-upgrader-core
)

package motd_packages do
  action :purge
end

file '/etc/default/motd-news' do
  content 'ENABLED=0'
end
