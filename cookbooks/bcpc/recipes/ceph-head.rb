#
# Cookbook Name:: bcpc
# Recipe:: ceph-head
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
#

include_recipe 'bcpc::packages_ceph'
include_recipe 'bcpc::ceph_keys'
include_recipe 'bcpc::ceph-common'

bash 'ceph-mon-mkfs' do
    user 'ceph'
    code <<-EOH
        mkdir -p /var/lib/ceph/mon/ceph-#{node['hostname']}
        ceph-mon --mkfs -i "#{node['hostname']}" --keyring "/etc/ceph/ceph.mon.keyring"
    EOH
    not_if "test -f /var/lib/ceph/mon/ceph-#{node['hostname']}/keyring"
end

service "ceph-mon@#{node['hostname']}" do
  action %w[enable start]
end

file '/usr/local/bin/ceph-mon-renice.sh' do
  ceph_mon_renice = node['bcpc']['ceph']['mon_niceness']
  content <<-EOH.gsub(/^\s+/,'')
    #!/bin/bash
    /usr/bin/pgrep ceph-mon | xargs renice #{ceph_mon_renice}
  EOH
  mode '0755'
end

systemd_unit 'ceph-mon-renice.service' do

  content <<-EOH.gsub(/^\s+/,'')
    [Unit]
    Description=Ceph MON Renicer
    After=ceph-mon.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/ceph-mon-renice.sh

    [Install]
    WantedBy=multi-user.target
  EOH

  action [:create, :enable]
end

ruby_block "add-ceph-mon-hints" do
  block do
    get_ceph_mon_nodes.each do |server|
      system "ceph --admin-daemon /var/run/ceph/ceph-mon.#{node['hostname']}.asok " +
             "add_bootstrap_peer_hint #{server['bcpc']['storage']['ip']}:6789"
    end
  end
  # not_if checks to see if all head node IPs are in the mon list
  not_if {
    mon_list = %x[ceph mon stat]
    get_ceph_mon_nodes.collect{ |x| x['bcpc']['storage']['ip'] }.map{ |ip| mon_list.include? ip }.uniq == [true]
  }
end

ruby_block "wait-for-mon-quorum" do
    block do
        clock = 0
        sleep_time = 2
        timeout = 120
        status = { 'state' => '' }
        until %w{leader peon}.include?(status['state']) do
            if clock >= timeout
              fail "Exceeded quorum wait timeout of #{timeout} seconds, check Ceph status with ceph -s and ceph health detail"
            end
            Chef::Log.warn("Waiting for ceph-mon to get quorum...")
            status = JSON.parse(%x[ceph --admin-daemon /var/run/ceph/ceph-mon.#{node['hostname']}.asok mon_status])
            clock += sleep_time
            sleep sleep_time unless %w{leader peon}.include?(status['state'])
        end
    end
end

%w(quorum_status monstatus).each do |script|
  template "/etc/sudoers.d/#{script}" do
    source "sudoers-#{script}.erb"
    mode 0440
    owner 'root'
    group 'root'
  end
end

%w(
  get_quorum_status get_monstatus
  if_leader if_not_leader if_quorum if_not_quorum
).each do |script|
  template "/usr/local/bin/#{script}" do
    source "ceph-#{script}.erb"
    mode 0755
    owner 'root'
    group 'root'
  end
end

bash "ceph-get-crush-map" do
  code <<-EOH
    false; while (($?!=0)); do
      echo Trying to get crush map...
      sleep 1
      ceph osd getcrushmap -o /tmp/crush-map
    done
    crushtool -d /tmp/crush-map -o /tmp/crush-map.txt
  EOH
end

bash 'set-ceph-crush-tunables' do
  user 'ceph'
  code <<-EOH
    ceph --name mon. --keyring \
    /var/lib/ceph/mon/ceph-#{node['hostname']}/keyring \
    osd crush tunables optimal
  EOH
  # do not apply if any tunables have been modified from their defaults
  not_if do
    show_tunables = Mixlib::ShellOut.new('ceph osd crush show-tunables')
    show_tunables.run_command
    raise 'Could not check Ceph tunables' if show_tunables.error!
    JSON.load(show_tunables.stdout) != node['bcpc']['ceph']['expected_tunables']
  end
end

include_recipe 'bcpc::ceph_mgr'

node['bcpc']['ceph']['enabled_pools'].each do |bucket|
  user 'ceph'
  bash "crush-add-bucket-#{bucket}" do
    user 'ceph'
    code <<-EOH
      ceph osd crush add-bucket #{bucket} root
    EOH
    not_if {
     system "grep -q 'root #{bucket}' /tmp/crush-map.txt"
    }
  end
  bash "crush-add-rule-#{bucket}" do
    user 'ceph'
    code <<-EOH
      ceph osd crush rule create-replicated #{bucket} #{bucket} \
      #{node['bcpc']['ceph']['chooseleaf']}
    EOH
    not_if {
     system "grep -q '^rule #{bucket}' /tmp/crush-map.txt"
    }
  end
end

# create vms ceph pool
#
vms_pool = node['bcpc']['ceph']['vms']

bash "create-rados-pool-#{vms_pool['name']}" do
  name      = vms_pool['name']
  type      = vms_pool['type']
  rule      = node['bcpc']['ceph'][type]['rule']
  pg_count  = get_ceph_optimal_pg_count(name)
  pgp_count = pg_count

  code <<-EOH
    ceph osd pool create #{name} #{pg_count} #{pgp_count} #{rule}
    sleep 15
  EOH

  not_if "ceph osd lspools | grep #{name}"
end

bash "set rados-pool-#{vms_pool['name']} pool replication" do
  name      = vms_pool['name']
  rep_count = get_ceph_replica_count('default')

  code <<-EOH
    ceph osd pool set #{name} size #{rep_count}
  EOH

  not_if "ceph osd pool get #{name} size | grep #{rep_count}"
end

if node['bcpc']['ceph']['pgp_auto_adjust']
  name = vms_pool['name']
  target_pg = get_ceph_optimal_pg_count(name)
  %w[pg_num pgp_num].each do |pg|
    current_pg = %x(`ceph osd pool get #{name} #{pg} | awk '{print $2}'`).to_i
    bash "set-#{name}-rados-pool-#{pg}" do
      code <<-EOH
        ceph osd pool set #{name} #{pg} #{target_pg}
      EOH
      only_if { current_pg < target_pg }
    end
  end
end


# Add application tags to Ceph OSD pools
bash 'add-application-tags-to-pools' do
  code <<-EOH
    for pool in `ceph osd pool ls`; do \
      ceph osd pool application enable $pool rbd; \
    done
  EOH
end

file "/var/lib/ceph/mon/ceph-#{node['hostname']}/done" do
  owner 'root'
  group 'root'
  mode 0644
  action :create
end


=begin
bash "initialize-ceph-glance-keyring" do
  code <<-EOH
    ceph-authtool /etc/ceph/ceph.client.glance.keyring \
    --create-keyring --gen-key \
    --name client.glance --set-uid=0 \
    --cap mon 'allow r' \
    --cap osd 'allow class-read object_prefix rbd_children, \
               allow rwx pool=images' \ > /dev/null
  EOH
  not_if {
    system "ceph-authtool /etc/ceph/ceph.client.glance.keyring -l \
            >/dev/null 2>&1"
  }
end

bash 'add ceph glance user' do
  code <<-EOH
    ceph auth add client.glance -i /etc/ceph/ceph.client.glance.keyring
  EOH
  not_if 'ceph auth get client.glance'
end

%w(cinder glance).each do |svc|
  get_key_cmd = "ceph-authtool -n client.#{svc} -p /etc/ceph/ceph.client.#{svc}.keyring"
  ruby_block "store-ceph-#{svc}-key" do
    block do
      make_config("#{svc}-ceph-key", `#{get_key_cmd}`, force=true)
    end
    only_if { File.exist?("/etc/ceph/ceph.client.#{svc}.keyring") and
              ((config_defined("#{svc}-ceph-key") and
              (get_config("#{svc}-ceph-key") != `#{get_key_cmd}`)) or
              (not config_defined("#{svc}-ceph-key")))
    }
  end
end
=end
