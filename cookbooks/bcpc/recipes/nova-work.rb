#
# Cookbook Name:: bcpc
# Recipe:: nova-work
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

package "nova-compute-#{node['bcpc']['virt_type']}" do
    action :upgrade
end

%w{nova-api nova-compute nova-novncproxy}.each do |pkg|
    package pkg do
        action :upgrade
    end
    service pkg do
        action [:enable, :start]
        subscribes :restart, "template[/etc/nova/nova.conf]", :delayed
        subscribes :restart, "template[/etc/nova/api-paste.ini]", :delayed
        subscribes :restart, "template[/etc/nova/policy.json]", :delayed
    end
end

service "nova-api" do
    restart_command "service nova-api restart; sleep 5"
end

%w{novnc pm-utils memcached sysfsutils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

cookbook_file "/tmp/nova-libvirt.patch" do
    source "nova-libvirt.patch"
    owner "root"
    mode 00644
end

bash "patch-for-nova-live-migration" do
   user "root"
   code <<-EOH
       cd /usr/lib/python2.7/dist-packages/nova
       patch -p2 < /tmp/nova-libvirt.patch
       rv=$?
       if [ $rv -ne 0 ]; then
         echo "Error applying patch ($rv) - aborting!"
         exit $rv
       fi
       cp /tmp/nova-libvirt.patch .
   EOH
   not_if "test -f /usr/lib/python2.7/dist-packages/nova/nova-libvirt.patch"
   notifies :restart, "service[nova-compute]", :immediately
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
    variables(:servers => search_nodes("recipe", "nova-work"))
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

bash "set-libvirt-bin-ulimit" do
    user "root"
    code <<-EOH
        sed --in-place '/^ulimit/d' /etc/default/libvirt-bin
        echo "ulimit -n #{node['bcpc']['libvirt-bin']['ulimit']['nofile']}" >> /etc/default/libvirt-bin
    EOH
    not_if "grep -e \"^ulimit -n #{node['bcpc']['libvirt-bin']['ulimit']['nofile']}$\" /etc/default/libvirt-bin"
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

cookbook_file "/usr/local/bin/nova-service-restart" do
  source "nova-service-restart"
  owner "root"
  mode "00755"
end

template "/usr/local/bin/nova-service-restart-wrapper" do
    source "nova-service-restart-wrapper.erb"
    owner "root"
    group "root"
    mode 00700
end

cron "restart-nova-kludge" do
  action :create
  command "/usr/local/bin/nova-service-restart-wrapper"
  minute '*/5'   # run this every 5 mins
end

include_recipe "bcpc::cobalt"
