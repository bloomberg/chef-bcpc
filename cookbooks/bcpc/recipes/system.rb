#
# Cookbook Name:: bcpc
# Recipe:: system
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

# if a particular kernel version is being specified, place holds on the
# packages so that nothing can automatically remove them
if node['bcpc']['kernel_version']
  ["linux-image-#{node['bcpc']['kernel_version']}",
   "linux-image-extra-#{node['bcpc']['kernel_version']}",
   "linux-headers-#{node['bcpc']['kernel_version']}",
   "linux-tools-#{node['bcpc']['kernel_version']}"].each do |pkg|
    package pkg

    bash "place-hold-on-#{pkg}" do
      code "echo #{pkg} hold | dpkg --set-selections"
      not_if "dpkg -s #{pkg} | grep ^Status: | grep -q ' hold '"
    end
  end
end

package "linux-image-extra-#{node['kernel']['release']}"

# ensure ipmi_devintf module is inserted to create /dev/ipmi0 for monitoring
# (on platforms without IPMI, the module will load but not create the dev node)
bash 'modprobe-ipmi_devintf' do
  code 'modprobe ipmi_devintf'
  not_if 'lsmod | grep ipmi_devintf'
end

bash 'add-ipmi_devintf-module' do
    code 'echo "ipmi_devintf" >> /etc/modules'
    not_if 'grep -e "^ipmi_devintf$" /etc/modules'
end

bash 'add-ipmi_si-module' do
    code 'echo "ipmi_si" >> /etc/modules'
    not_if 'grep -e "^ipmi_si$" /etc/modules'
end

template "/etc/default/grub" do
  source "system.etc_default_grub.erb"
  owner  "root"
  group  "root"
  mode   00644
  notifies :run, "execute[system-update-grub]", :immediately
end

execute "system-update-grub" do
  command "update-grub"
  user "root"
  action :nothing
end

template "/etc/sysctl.d/70-bcpc.conf" do
    source "sysctl-70-bcpc.conf.erb"
    owner "root"
    group "root"
    mode 00644
    variables(
        :additional_reserved_ports => node['bcpc']['system']['additional_reserved_ports'],
        :parameters                => node['bcpc']['system']['parameters']
    )
    notifies :run, "execute[reload-sysctl]", :immediately
end

execute "reload-sysctl" do
    action :nothing
    command "sysctl -p /etc/sysctl.d/70-bcpc.conf"
end

template "/etc/udev/rules.d/99-readahead.rules" do
    source "readahead-udev.rules.erb"
    owner "root"
    group "root"
    mode 00644
end

begin
  sys_params = node['bcpc']['system']['parameters']
  nf_conntrack_max = sys_params['net.nf_conntrack_max']
  hashsize = nf_conntrack_max / 4

  template '/etc/modprobe.d/nf_conntrack.conf' do
    source 'modprobe.d/nf_conntrack.conf.erb'
    variables(
      :hashsize => hashsize
    )
  end

  execute 'set nf conntrack hashsize' do
    hashsize_fp = '/sys/module/nf_conntrack/parameters/hashsize'
    command "echo #{hashsize} > #{hashsize_fp}"
    not_if "grep -w #{hashsize} #{hashsize_fp}"
  end
end

cookbook_file '/etc/rc.local' do
  source 'system.etc_rc.local'
  owner  'root'
  group  'root'
  mode   '0755'
end

cookbook_file '/usr/local/bin/mm-thp-madvise.sh' do
  source 'system.mm-thp-madvise.sh'
  owner  'root'
  group  'root'
  mode   '0755'
  notifies :run, 'bash[mm-tuning]', :delayed
end

cookbook_file '/usr/local/bin/mm-disable-ksm-merge-across-nodes.sh' do
  source 'system.mm-disable-ksm-merge-across-nodes.sh'
  owner  'root'
  group  'root'
  mode   '0755'
  notifies :run, 'bash[mm-tuning]', :delayed
end

bash 'mm-tuning' do
  code <<-EOH
    /usr/local/bin/mm-thp-madvise.sh
    /usr/local/bin/mm-disable-ksm-merge-across-nodes.sh
  EOH
  action :nothing
end

ruby_block "swap-toggle" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/fstab")
    if node['bcpc']['enabled']['swap'] then
      rc.search_file_replace(
        /^#([A-Z].*|\/.*)swap(.*)/,
        '\\1swap\\2'
      )
      rc.write_file
      system 'swapon -a'
    else
      system 'swapoff -a'
      rc.search_file_replace(
        /^([A-Z].*|\/.*)swap(.*)/,
        '#\\1swap\\2'
      )
      rc.write_file
    end
  end
end

# converge I/O scheduler
ruby_block 'converge-io-scheduler' do
  block do
    block_devices = ::Dir.glob('/dev/sd?').map { |d| d.split('/').last }
    block_devices.each do |device|
      %x[ echo #{node['bcpc']['hardware']['io_scheduler']} > /sys/block/#{device}/queue/scheduler ]
    end
  end
  not_if do
    block_devices = ::Dir.glob('/dev/sd?').map { |d| d.split('/').last }
    devices_to_converge = []
    block_devices.each do |device|
      scheduler = %x[ cat /sys/block/#{device}/queue/scheduler ]
      if scheduler.index("[#{node['bcpc']['hardware']['io_scheduler']}]").nil?
        devices_to_converge << device
      end
    end
    devices_to_converge.length.zero?
  end
end

template '/etc/updatedb.conf' do
  source 'updatedb.conf.erb'
  owner 'root'
  group 'root'
  mode 00644
end
