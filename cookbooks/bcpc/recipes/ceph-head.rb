#
# Cookbook Name:: bcpc
# Recipe:: ceph-mon
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

include_recipe "bcpc::ceph-common"

bash 'ceph-mon-mkfs' do
    code <<-EOH
        mkdir -p /var/lib/ceph/mon/ceph-#{node[:hostname]}
        ceph-mon --mkfs -i "#{node[:hostname]}" --keyring "/etc/ceph/ceph.mon.keyring"
    EOH
    not_if "test -f /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring"
end

execute "ceph-mon-start" do
    command "initctl emit ceph-mon id='#{node[:hostname]}'"
end

ruby_block "add-ceph-mon-hints" do
    block do
        get_head_nodes.each do |server|
            system "ceph --admin-daemon /var/run/ceph/ceph-mon.#{node[:hostname]}.asok \
                add_bootstrap_peer_hint #{server['bcpc']['storage']['ip']}:6789" 
        end
    end
end

ruby_block "wait-for-mon-quorum" do
    block do
        begin
            puts "Waiting for ceph-mon to get quorum..."
            status = JSON.parse(%x[ceph --admin-daemon /var/run/ceph/ceph-mon.#{node[:hostname]}.asok mon_status])
            sleep 2 if not %w{leader peon}.include?(status['state'])
        end while not %w{leader peon}.include?(status['state'])
    end
end

%w{get_monstatus if_leader if_not_leader if_quorum if_not_quorum}.each do |script|
    template "/usr/local/bin/#{script}" do
        source "ceph-#{script}.erb"
        mode 0755
        owner "root"
        group "root"
    end
end

template "/etc/sudoers.d/monstatus" do
    source "sudoers-monstatus.erb"
    user "root"
    group "root"
    mode 00440
end

ruby_block "reap-dead-ceph-mon-servers" do
    block do
        head_names = get_head_nodes.collect{|x| x['hostname']}
        status = JSON.parse(%x[ceph --admin-daemon /var/run/ceph/ceph-mon.#{node[:hostname]}.asok mon_status])
        status['monmap']['mons'].collect{|x| x['name']}.each do |server|
            if not head_names.include?(server)
                %x[ ceph mon remove #{server} ]
            end
        end
    end
end

bash "initialize-ceph-admin-and-osd-config" do
    code <<-EOH
        ceph --name mon. --keyring /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring \
            auth get-or-create-key client.admin \
            mon 'allow *' \
            osd 'allow *' \
            mds 'allow' > /dev/null
        ceph --name mon. --keyring /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring \
            auth get-or-create-key client.bootstrap-osd \
            mon 'allow profile bootstrap-osd' > /dev/null
    EOH
end

bash "set-ceph-crush-tunables" do
    code <<-EOH
        ceph --name mon. --keyring /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring \
            osd crush tunables optimal
    EOH
end

directory "/var/lib/ceph/mds/ceph-#{node[:hostname]}" do
    user "root"
    group "root"
    mode 00755
end

bash "initialize-ceph-mds-config" do
    code <<-EOH
        ceph --name mon. --keyring /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring \
            auth get-or-create-key mds.#{node[:hostname]} \
            mon 'allow *' \
            osd 'allow *' \
            mds 'allow' > /dev/null
    EOH
end

bash "write-mds-#{node[:hostname]}-key" do
    code <<-EOH
        MDS_KEY=`ceph --name mon. --keyring /var/lib/ceph/mon/ceph-#{node[:hostname]}/keyring auth get-or-create-key mds.#{node[:hostname]}`
        ceph-authtool "/var/lib/ceph/mds/ceph-#{node[:hostname]}/keyring" \
            --create-keyring \
            --name=mds.#{node[:hostname]} \
            --add-key="$MDS_KEY"
    EOH
    not_if "test -f /var/lib/ceph/mds/ceph-#{node[:hostname]}/keyring"
end

execute "ceph-mds-start" do
    command "initctl emit ceph-mds id='#{node[:hostname]}'"
end

template "/tmp/crush-map-additions.txt" do
    source "ceph-crush.erb"
    owner "root"
    mode 00644
end

bash "ceph-get-crush-map" do
    code <<-EOH
        ceph osd getcrushmap -o /tmp/crush-map
        crushtool -d /tmp/crush-map -o /tmp/crush-map.txt
    EOH
end

bash "ceph-add-crush-rules" do
    code <<-EOH
        cat /tmp/crush-map-additions.txt >> /tmp/crush-map.txt
        crushtool -c /tmp/crush-map.txt -o /tmp/crush-map-new
        ceph osd setcrushmap -i /tmp/crush-map-new
    EOH
    not_if "grep ssd /tmp/crush-map.txt"
end

if get_head_nodes.length == 1; then
    rule = (node[:bcpc][:ceph][:ssd_disks].length > 0) ? 3 : 4
    %w{data metadata rbd}.each do |pool|
        bash "move-#{pool}-rados-pool" do
            user "root"
            code "ceph osd pool set #{pool} crush_ruleset #{rule}"
        end
    end
end

%w{mon mds}.each do |svc|
    %w{done upstart}.each do |name|
        file "/var/lib/ceph/#{svc}/ceph-#{node[:hostname]}/#{name}" do
            owner "root"
            group "root"
            mode "0644"
            action :create
        end
    end
end

include_recipe "bcpc::ceph-work"
