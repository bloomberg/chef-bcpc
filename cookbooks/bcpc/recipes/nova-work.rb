#
# Cookbook Name:: bcpc
# Recipe:: nova-head
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
        restart_command "service #{pkg} stop; sleep 5; service #{pkg} start"
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
    nofile_soft_limit: node['bcpc']['nova']['compute']['limits']['nofile']['soft'],
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

template "/etc/nova/ssl-bcpc.pem" do
    source "ssl-bcpc.pem.erb"
    owner "nova"
    group "nova"
    mode 00644
end

template "/etc/nova/ssl-bcpc.key" do
    source "ssl-bcpc.key.erb"
    owner "nova"
    group "nova"
    mode 00600
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

template "/etc/default/libvirt-bin" do
  source "libvirt-bin-default.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[libvirt-bin]", :delayed
end

template "/etc/libvirt/libvirtd.conf" do
    source "libvirtd.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[libvirt-bin]", :delayed
end

service "libvirt-bin" do
    action [:enable, :start]
    restart_command "/etc/init.d/libvirt-bin restart"
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
    notifies :restart, "service[libvirt-bin]", :delayed
end

# we have to adjust apparmor to allow qemu to write rbd logs/sockets
service "apparmor" do
  action :nothing
end

template "/etc/apparmor.d/abstractions/libvirt-qemu" do
  source "apparmor-libvirt-qemu.#{node['bcpc']['openstack_release']}.erb"
  notifies :restart, "service[libvirt-bin]", :delayed
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

  cookbook_file '/usr/lib/python2.7/dist-packages/nova/network/model.py' do
    source 'nova-network-model.py'
    notifies :restart, 'service[nova-network]', :immediately
  end
end

include_recipe 'bcpc::calico-compute' if node['bcpc']['enabled']['neutron']
