#
# Cookbook Name:: bcpc-ceph
# Recipe:: osd
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

include_recipe 'bcpc-ceph'
include_recipe 'bcpc-ceph::write-bootstrap-osd-key'
include_recipe 'bcpc-ceph::write-client-admin-key'

%w{ssd hdd}.each do |type|
    node['bcpc']['ceph']["#{type}_disks"].each do |disk|
        execute "ceph-disk-prepare-#{type}-#{disk}" do
            command <<-EOH
                ceph-disk-prepare /dev/#{disk}
                ceph-disk-activate /dev/#{disk}
                sleep 2
                INFO=`df -k | grep /dev/#{disk} | awk '{print $2,$6}' | sed -e 's/\\/var\\/lib\\/ceph\\/osd\\/ceph-//'`
                OSD=${INFO#* }
                WEIGHT=`echo "scale=4; ${INFO% *}/1000000000.0" | bc -q`
                ceph osd crush create-or-move $OSD $WEIGHT root=#{type} rack=#{node['bcpc']['rack_name']}-#{type} host=#{node['hostname']}-#{type}
            EOH
            not_if "sgdisk -i1 /dev/#{disk} | grep -i 4fbd7e29-9d25-41b8-afd0-062c0ceff05d"
        end
    end
end

execute "trigger-osd-startup" do
    command "udevadm trigger --subsystem-match=block --action=add"
end

template '/etc/init/ceph-osd-renice.conf' do
  source 'ceph-upstart.ceph-osd-renice.conf.erb'
  mode 00644
  notifies :restart, "service[ceph-osd-renice]", :immediately
end

service 'ceph-osd-renice' do
  provider Chef::Provider::Service::Upstart
  action [:enable, :start]
  restart_command 'service ceph-osd-renice restart'
end
