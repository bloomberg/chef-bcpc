# Cookbook Name:: bcpc
# Recipe:: nova-work
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
#

package 'nova-compute'
package 'nova-api-metadata'
package 'pm-utils'
package 'memcached'
package 'sysfsutils'

service 'nova-compute'
service 'nova-api-metadata'
service 'libvirtd'

# configure nova user starts
#
user "nova" do
  shell '/bin/bash'
end

# add the nova user to the ceph group so nova can read
# cinders ceph client key file
#
group 'ceph' do
  action :modify
  members 'nova'
  append true
end

directory "/var/lib/nova/.ssh" do
  owner "nova"
  group "nova"
  mode 00700
end

template "/var/lib/nova/.ssh/authorized_keys" do
  source "nova-authorized_keys.erb"
  owner "nova"
  group "nova"
  mode 00644
end

template "/var/lib/nova/.ssh/id_rsa" do
  source "nova-id_rsa.erb"
  owner "nova"
  group "nova"
  mode 00600
end

template "/var/lib/nova/.ssh/config" do
  source "nova-ssh_config.erb"
  owner "nova"
  group "nova"
  mode 00600
end
#
# configure nova user ends


# configure libvirt starts
#
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

execute 'export client.cinder ceph keyring' do
  user 'root'
  group 'ceph'
  command <<-EOH
    ceph auth get client.cinder -o \
      /etc/ceph/ceph.client.cinder.keyring
  EOH
end

template "/etc/nova/virsh-secret.xml" do
  source "virsh-secret.xml.erb"
  notifies :run, "bash[load virsh secrets]", :immediately
  not_if "virsh secret-list | grep -i #{get_config('libvirt-secret-uuid')}"
end

bash "load virsh secrets" do
  action :nothing

  code <<-EOH
    virsh secret-define --file /etc/nova/virsh-secret.xml
    virsh secret-set-value \
      --secret #{get_config('libvirt-secret-uuid')} \
      --base64 $(ceph auth get-key client.cinder)
  EOH
end

bash "remove-default-virsh-net" do
  code <<-EOH
      virsh net-destroy default
      virsh net-undefine default
  EOH
  only_if "virsh net-list | grep -i default"
end
#
# configure libvirt ends

template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'
  variables(
    'servers' => get_head_nodes()
  )
  notifies :restart, 'service[nova-compute]', :immediately 
end

template '/etc/nova/nova-compute.conf' do
  source 'nova/nova-compute.conf.erb'
  notifies :restart, 'service[nova-compute]', :immediately 
  notifies :restart, 'service[nova-api-metadata]', :immediately 
end

template "/etc/nova/policy.json" do
  source "nova-policy.json.erb"
  owner "nova"
  group "nova"
  mode 00600
  variables(:policy => JSON.pretty_generate(node['bcpc']['nova']['policy']))
end

execute 'wait for compute host' do
  environment (os_adminrc())
  retries 15
  command <<-EOH
    openstack compute service list \
      --service nova-compute | grep #{node['hostname']}
  EOH
end

execute 'discover compute hosts' do
  command <<-EOH
    su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
  EOH
end

=begin
include_recipe "bcpc::ceph-work"
include_recipe "bcpc::nova-common"

# see https://specs.openstack.org/openstack/nova-specs/specs/juno/implemented/virt-driver-numa-placement.html
# for information about NUMA in OpenStack
package 'numactl' do
  action :install
end

package "nova-compute-#{node['bcpc']['virt_type']}" do
  action :install
end

nova_services = %w(nova-api nova-compute nova-novncproxy)
nova_services += ['nova-network'] unless node['bcpc']['enabled']['neutron']
nova_services.each do |pkg|
    package pkg do
        action :install
    end
    service pkg do
        action [:enable, :start]
        restart_command "systemctl stop #{pkg}; sleep 5; systemctl start #{pkg}"
        subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
        subscribes :restart, "template[/etc/nova/api-paste.ini]", :delayed
    end
end

template '/etc/init/nova-compute.conf' do
  source 'nova-compute-upstart.conf.erb'
  owner  'root'
  group  'root'
  mode   '00644'
  variables(
    nefile_soft_limit: node['bcpc']['nova']['compute']['limits']['nofile']['soft'],
    nofile_hard_limit: node['bcpc']['nova']['compute']['limits']['nofile']['hard']
  )
  notifies :restart, 'service[nova-compute]', :immediately
end

cookbook_file '/usr/local/bin/wait_for_api.sh' do
  source 'wait_for_api.sh'
  owner  'root'
  group  'root'
  mode   '00755'
end

service "nova-api" do
    restart_command "service nova-api restart; /usr/local/bin/wait_for_api.sh 169.254.169.254:8775"
end

%w{novnc pm-utils memcached sysfsutils}.each do |pkg|
    package pkg do
        action :install
    end
end

directory "/var/lib/nova/.ssh" do
    owner "nova"
    group "nova"
    mode 00700
end

template "/var/lib/nova/.ssh/authorized_keys" do
    source "nova-authorized_keys.erb"
    owner "nova"
    group "nova"
    mode 00644
end

template "/var/lib/nova/.ssh/known_hosts" do
    source "known_hosts.erb"
    owner "nova"
    group "nova"
    mode 00644
    variables(
      lazy {
        {
          :servers => search_nodes("recipe", "nova-work")
        }
      }
    )
end

template "/var/lib/nova/.ssh/id_rsa" do
    source "nova-id_rsa.erb"
    owner "nova"
    group "nova"
    mode 00600
end

template "/var/lib/nova/.ssh/config" do
    source "nova-ssh_config.erb"
    owner "nova"
    group "nova"
    mode 00600
end

template "/etc/default/libvirtd" do
  source "libvirtd-default.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[libvirtd]", :delayed
end

template "/etc/libvirt/libvirtd.conf" do
    source "libvirtd.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[libvirtd]", :delayed
end

service "libvirtd" do
    action [:enable, :start]
end

template "/etc/nova/virsh-secret.xml" do
  source "virsh-secret.xml.erb"
  owner "nova"
  group "nova"
  mode 00600
end

bash "set-nova-user-shell" do
    user "root"
    code <<-EOH
        chsh -s /bin/bash nova
    EOH
    not_if "grep nova /etc/passwd | grep /bin/bash"
end

template "/etc/ceph/ceph.client.cinder.keyring" do
  source "ceph-client-cinder-keyring.erb"
  mode "00644"
end

ruby_block 'load-virsh-keys' do
    block do
        %x[ CINDER_KEY=`ceph --name mon. --keyring /etc/ceph/ceph.mon.keyring auth get-or-create-key client.cinder`
            virsh secret-define --file /etc/nova/virsh-secret.xml
            virsh secret-set-value --secret #{get_config('libvirt-secret-uuid')} --base64 "$CINDER_KEY"
        ]
    end
    not_if { system "virsh secret-list | grep -i #{get_config('libvirt-secret-uuid')} >/dev/null" }
end

bash "remove-default-virsh-net" do
    user "root"
    code <<-EOH
        virsh net-destroy default
        virsh net-undefine default
    EOH
    only_if "virsh net-list | grep -i default"
end

bash "libvirt-device-acls" do
    user "root"
    code <<-EOH
        echo "cgroup_device_acl = [" >> /etc/libvirt/qemu.conf
        echo "   \\\"/dev/null\\\", \\\"/dev/full\\\", \\\"/dev/zero\\\"," >> /etc/libvirt/qemu.conf
        echo "   \\\"/dev/random\\\", \\\"/dev/urandom\\\"," >> /etc/libvirt/qemu.conf
        echo "   \\\"/dev/ptmx\\\", \\\"/dev/kvm\\\", \\\"/dev/kqemu\\\"," >> /etc/libvirt/qemu.conf
        echo "   \\\"/dev/rtc\\\", \\\"/dev/hpet\\\", \\\"/dev/net/tun\\\"" >> /etc/libvirt/qemu.conf
        echo "]" >> /etc/libvirt/qemu.conf
    EOH
    not_if "grep -e '^cgroup_device_acl' /etc/libvirt/qemu.conf"
    notifies :restart, "service[libvirtd]", :delayed
end

# we have to adjust apparmor to allow qemu to write rbd logs/sockets
service "apparmor" do
  action :nothing
end

template "/etc/apparmor.d/abstractions/libvirt-qemu" do
  source "apparmor-libvirt-qemu.#{node['bcpc']['openstack_release']}.erb"
  notifies :restart, "service[libvirtd]", :delayed
  notifies :restart, "service[apparmor]", :delayed
end

if node['bcpc']['virt_type'] == "kvm" then
    %w{amd intel}.each do |arch|
        bash "enable-kvm-#{arch}" do
            user "root"
            code <<-EOH
                modprobe kvm_#{arch}
                echo 'kvm_#{arch}' >> /etc/modules
            EOH
            not_if "grep -e '^kvm_#{arch}' /etc/modules"
        end
    end
end

# these patches only apply to nova-network so do not apply if Neutron+Calico is on
unless node['bcpc']['enabled']['neutron']
  # patches metadata service with BCPC hostname style
  bcpc_patch 'nova-api-metadata-base-mitaka' do
    patch_file           'nova-api-metadata-base-mitaka.patch'
    patch_root_dir       '/usr/lib/python2.7/dist-packages'
    shasums_before_apply 'nova-api-metadata-base-mitaka-BEFORE.SHASUMS'
    shasums_after_apply  'nova-api-metadata-base-mitaka-AFTER.SHASUMS'
    notifies :restart, 'service[nova-api]', :immediately
    only_if "dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') ge 2:13.1.1 && dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') lt 2:14.0.0"
  end

  # patches nova-network with BCPC hostname style and dnsmasq fix
  bcpc_patch 'nova-network-linux_net-mitaka' do
    patch_file           'nova-network-linux_net-mitaka.patch'
    patch_root_dir       '/usr/lib/python2.7/dist-packages'
    shasums_before_apply 'nova-network-linux_net-mitaka-BEFORE.SHASUMS'
    shasums_after_apply  'nova-network-linux_net-mitaka-AFTER.SHASUMS'
    notifies :restart, 'service[nova-network]', :immediately
    only_if "dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') ge 2:13.1.1 && dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') lt 2:14.0.0"
  end

  # patches nova-network to teardown bridges
  bcpc_patch 'nova-network-manager-mitaka' do
    patch_file           'nova-network-manager-mitaka.patch'
    patch_root_dir       '/usr/lib/python2.7/dist-packages'
    shasums_before_apply 'nova-network-manager-mitaka-BEFORE.SHASUMS'
    shasums_after_apply  'nova-network-manager-mitaka-AFTER.SHASUMS'
    notifies :restart, 'service[nova-network]', :immediately
    only_if "dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') ge 2:13.1.1 && dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') lt 2:14.0.0"
  end

  # patches python-nova to stop multiple fixed addresses being associated
  # with an instance if the initial build has issues
  # https://review.openstack.org/#/c/393805/
  bcpc_patch 'python-nova-objects-instance-mitaka' do
    patch_file           'python-nova-objects-instance-mitaka.patch'
    patch_root_dir       '/usr/lib/python2.7/dist-packages'
    shasums_before_apply 'python-nova-objects-instance-mitaka-BEFORE.SHASUMS'
    shasums_after_apply  'python-nova-objects-instance-mitaka-AFTER.SHASUMS'
    only_if "dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') ge 2:13.1.1 && dpkg --compare-versions $(dpkg -s python-nova | egrep '^Version:' | awk '{ print $NF }') lt 2:14.0.0"
  end
end

include_recipe 'bcpc::calico-compute' if node['bcpc']['enabled']['neutron']
=end
