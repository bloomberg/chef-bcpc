#
# Cookbook Name:: bcpc-ceph
# Recipe:: default
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

apt_repository "ceph" do
  uri node['bcpc']['repos']['ceph']
  distribution node['lsb']['codename']
  components ["main"]
  key "ceph-release.key"
end

if platform?("debian", "ubuntu")
    include_recipe "bcpc-networking"
end

bash "check-ceph-version" do
    code <<-EOH
        /usr/local/bin/apt-pkg-check-version ceph #{node['bcpc']['ceph']['version_number']}
        exit $?
	EOH
end

# Installing CephFS but not activating it
%w{librados2 librbd1 libcephfs1 python-ceph ceph ceph-common ceph-fs-common ceph-mds}.each do |pkg|
    package pkg do
        action :install
        version node['bcpc']['ceph']['version']
    end
end


ruby_block "initialize-ceph-common-config" do
    block do
        make_config('ceph-fs-uuid', generate_uuid)
        make_config('ceph-mon-key', ceph_keygen)
    end
end

directory '/etc/ceph' do
  owner 'root'
  group 'root'
  mode 00755
end

ruby_block 'write-ceph-mon-key' do
  block do
    cmd = Mixlib::ShellOut.new("ceph-authtool '/etc/ceph/ceph.mon.keyring' \
            --create-keyring \
            --name=mon. \
            --add-key='#{get_config('ceph-mon-key')}' \
            --cap mon 'allow *'").run_command
    cmd.error!
  end
  not_if "test -f /etc/ceph/ceph.mon.keyring"
end

template '/etc/ceph/ceph.conf' do
  source 'ceph.conf.erb'
  mode '0644'
  variables(
    lazy {
      {:servers => get_head_nodes}
    }
  )
end

directory "/var/run/ceph/" do
  owner "root"
  group "root"
  mode  "0755"
end

directory "/var/run/ceph/guests/" do
  owner "libvirt-qemu"
  group "libvirtd"
  mode  "0755"
end

directory "/var/log/qemu/" do
  owner "libvirt-qemu"
  group "libvirtd"
  mode  "0755"

end

bcpc_ceph_config 'paxos_propose_interval' do
  value node["bcpc"]["ceph"]["rebalance"] ? "60" : "1"
  target "ceph-mon*"
end

bcpc_ceph_config 'osd_recovery_max_active' do
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "15"
  target "ceph-osd*"
end

bcpc_ceph_config 'osd_max_backfills' do
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "10"
  target "ceph-osd*"
end

bcpc_ceph_config 'osd_op_threads' do
  value node["bcpc"]["ceph"]["rebalance"] ? "10" : "2"
  target "ceph-osd*"
end

bcpc_ceph_config 'osd_recovery_op_priority' do
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "10"
  target "ceph-osd*"
end

bcpc_ceph_config 'osd_mon_report_interval_min' do
  value node["bcpc"]["ceph"]["rebalance"] ? "30" : "5"
  target "ceph-osd*"
end

# Script looks for mdsmap and if MDS is removed later then this script will need to be changed.
bash "wait-for-pgs-creating" do
    action :nothing
    user "root"
    code "while ceph -s | grep -v mdsmap | grep creating >/dev/null 2>&1; do echo Waiting for new pgs to create...; sleep 1; done"
end
