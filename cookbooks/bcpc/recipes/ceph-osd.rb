#
# Cookbook Name:: bcpc
# Recipe:: ceph-osd

# Copyright 2016, Bloomberg Finance L.P.
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

rack_number = node['bcpc']['rack_name'].match(/^rack-(\d+)/)[1].to_i
ceph_rack = "rack-#{rack_number}"

node['bcpc']['ceph']['enabled_pools'].each do |type|
  node['bcpc']['ceph']["#{type}_disks"].each do |disk|
    execute "ceph-volume-create-#{type}-#{disk}" do
      command <<-EOH
        ceph-volume lvm create --bluestore --data /dev/#{disk}
        sleep 2
        PV="`pvdisplay /dev/#{disk} -C --no-headings | awk '{print $2}'`"
        BLOCK_DEV="`lvdisplay $PV | grep 'LV Path' | awk '{print $3}'`"
        OSD_ID="`ceph-volume lvm list \
          $BLOCK_DEV | grep 'osd id' | awk '{print $NF}')`"
        ceph osd crush set osd.$OSD_ID 1.0 \
          root=#{type} \
          rack=#{ceph_rack}-#{type} \
          host=#{node['hostname']}-#{type}
      EOH
      not_if "pvdisplay /dev/#{disk} >/dev/null 2>&1"
    end
  end
end

#execute "trigger-osd-startup" do
#    command "udevadm trigger --subsystem-match=block --action=add"
#end

ruby_block "set-primary-anti-affinity" do
    block do
        system "ceph tell mon.\* injectargs --mon_osd_allow_primary_affinity=true > /dev/null 2>&1"
        osds_tree = JSON.parse( %x[ceph osd tree --format json] )
        osds = osds_tree['nodes'].select{ |v| v["name"] == "#{node["hostname"]}-ssd" || v["name"] == "#{node["hostname"]}-hdd" }.collect{ |x| x["children"] }.flatten
        osds.each do |osd|
            system "ceph osd primary-affinity osd.#{osd} 0 > /dev/null 2>&1"
        end
    end
    only_if { node['bcpc']['ceph']['set_headnode_affinity'] and get_head_nodes.include?(node) }
end

file '/usr/local/bin/ceph-osd-renice.sh' do
  ceph_osd_renice = node['bcpc']['ceph']['osd_niceness']
  content <<-EOH.gsub(/^\s+/,'')
    #!/bin/bash
    /usr/bin/pgrep ceph-osd | xargs renice #{ceph_osd_renice}
  EOH
  mode '0755'
  not_if { get_head_nodes.include?(node) }
end

systemd_unit 'ceph-osd-renice.service' do
  action [:create, :enable]
  content <<-EOH.gsub(/^\s+/,'')
    [Unit]
    Description=Ceph OSD Renicer
    After=ceph-osd.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/ceph-osd-renice.sh

    [Install]
    WantedBy=multi-user.target
  EOH
  not_if { get_head_nodes.include?(node) }
end
