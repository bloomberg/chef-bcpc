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

include_recipe "bcpc::openstack"
include_recipe "bcpc::ceph-work"
include_recipe "bcpc::cobalt"

ruby_block "initialize-nova-work-config" do
    block do
        make_config('ssh-nova-private-key', %x[printf 'y\n' | ssh-keygen -t rsa -N '' -q -f /dev/stdout | sed -e '1,1d' -e 's/.*-----BEGIN/-----BEGIN/'])
        make_config('ssh-nova-public-key', %x[echo "#{get_config('ssh-nova-private-key')}" | ssh-keygen -y -f /dev/stdin])
    end
end

package "nova-compute-#{node[:bcpc][:virt_type]}" do
    action :upgrade
end

%w{nova-api nova-network nova-compute nova-novncproxy}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [ :enable, :start ]
    end
end

%w{novnc pm-utils memcached python-memcache sysfsutils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

template "/etc/nova/nova.conf" do
    source "nova.conf.erb"
    owner "nova"
    group "nova"
    mode 00600
    notifies :restart, "service[nova-api]", :delayed
    notifies :restart, "service[nova-compute]", :delayed
    notifies :restart, "service[nova-network]", :delayed
    notifies :restart, "service[nova-novncproxy]", :delayed
end

template "/etc/nova/api-paste.ini" do
    source "nova.api-paste.ini.erb"
    owner "nova"
    group "nova"
    mode 00600
    notifies :restart, "service[nova-api]", :delayed
    notifies :restart, "service[nova-compute]", :delayed
    notifies :restart, "service[nova-network]", :delayed
    notifies :restart, "service[nova-novncproxy]", :delayed
end

if not node['bcpc']['vms_key'].nil?
    apt_repository "vms" do
        uri node['bcpc']['repos']['gridcentric'] % [node['bcpc']['vms_key'], 'vms']
        distribution "gridcentric"
        components ["multiverse"]
        key "gridcentric.key"
    end

    template "/etc/nova/cobalt-compute.conf" do
        source "cobalt-compute.conf.erb"
        owner "root"
        group "root"
        mode 00644
    end

    directory "/etc/sysconfig" do
        owner "root"
        group "root"
        mode 00755
    end

    template "/etc/sysconfig/vms" do
        source "vms.erb"
        owner "root"
        group "root"
        mode 00644
    end

    %w{vms vms-apparmor vms-rados vms-libvirt}.each do |pkg|
        package pkg do
            action :upgrade
            options "-o APT::Install-Recommends=0 -o Dpkg::Options::='--force-confnew'"
        end
    end

    %w{cobalt-api cobalt-compute}.each do |pkg|
        package pkg do
            action :upgrade
            options "-o APT::Install-Recommends=0 -o Dpkg::Options::='--force-confnew'"
        end
    end

    service "cobalt-compute" do
        action [ :enable, :start ]
    end

    bash "restart-cobalt" do
        subscribes :run, resources("template[/etc/nova/nova.conf]"), :delayed
        subscribes :run, resources("template[/etc/nova/cobalt-compute.conf]"), :delayed
        subscribes :run, resources("template[/etc/sysconfig/vms]"), :delayed
        notifies :restart, "service[cobalt-compute]", :immediately
    end
end

service "nova-api" do
    restart_command "service nova-api stop && service nova-api start && sleep 5"
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

bash "enable-defaults-libvirt-bin" do
    user "root"
    code <<-EOH
        sed --in-place '/^libvirtd_opts=/d' /etc/default/libvirt-bin
        echo 'libvirtd_opts=\"-d -l\"' >> /etc/default/libvirt-bin
    EOH
    not_if "grep -e '^libvirtd_opts=\"-d -l\"' /etc/default/libvirt-bin"
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
    action [ :enable, :start ]
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

ruby_block 'load-virsh-keys' do
    block do
        if not system "virsh secret-list | grep -i #{get_config('libvirt-secret-uuid')}" then
            %x[ ADMIN_KEY=`ceph --name mon. --keyring /etc/ceph/ceph.mon.keyring auth get-or-create-key client.admin`
                virsh secret-define --file /etc/nova/virsh-secret.xml
                virsh secret-set-value --secret #{get_config('libvirt-secret-uuid')} \
                    --base64 "$ADMIN_KEY"
            ]
        end
    end
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

cookbook_file "/tmp/nova.patch" do
    source "nova.patch"
    owner "root"
    mode 00644
end

bash "patch-for-nova-bugs" do
    user "root"
    code <<-EOH
        cd /usr/lib/python2.7/dist-packages/nova
        patch -p1 < /tmp/nova.patch
        cp /tmp/nova.patch .
    EOH
    not_if "test -f /usr/lib/python2.7/dist-packages/nova/nova.patch"
    notifies :restart, "service[nova-api]", :immediately
end

cookbook_file "/tmp/grizzly-volumes.patch" do
    source "grizzly-volumes.patch"
    owner "root"
    mode 00644
end

bash "patch-for-grizzly-volumes" do
    user "root"
    code <<-EOH
        cd /usr/lib/python2.7/dist-packages/nova
        patch -p2 < /tmp/grizzly-volumes.patch
        cp /tmp/grizzly-volumes.patch .
    EOH
    not_if "test -f /usr/lib/python2.7/dist-packages/nova/grizzly-volumes.patch"
    notifies :restart, "service[nova-compute]", :delayed
end

bash "create-vms-disk-pool" do
    user "root"
    code <<-EOH
        ceph osd pool create #{node[:bcpc][:vms_disk_pool]} 1000
        ceph osd pool set #{node[:bcpc][:vms_disk_pool]} size 3
    EOH
    not_if "rados lspools | grep #{node[:bcpc][:vms_disk_pool]}"
end

bash "create-vms-mem-pool" do
    user "root"
    code <<-EOH
        ceph osd pool create #{node[:bcpc][:vms_mem_pool]} 1000
        ceph osd pool set #{node[:bcpc][:vms_mem_pool]} size 3
    EOH
    not_if "rados lspools | grep #{node[:bcpc][:vms_mem_pool]}"
end
