#
# Cookbook Name:: bcpc
# Recipe:: ceph-common
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

if platform?("debian", "ubuntu")
    include_recipe "bcpc::networking"
end

case node['platform']
when "centos", "redhat", "fedora", "suse", "amazon", "scientific"
    include_recipe "bcpc::ceph-yum"
when "debian", "ubuntu"
    include_recipe "bcpc::ceph-apt"
end

cookbook_file "/usr/local/bin/apt-pkg-check-version" do
    source "apt-pkg-check-version"
    owner "root"
    mode 00755
end

bash "check-ceph-version" do
    code <<-EOH
        /usr/local/bin/apt-pkg-check-version ceph 0.80
        exit $?
	EOH
end

%w{ceph python-ceph}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

ruby_block "initialize-ceph-common-config" do
    block do
        make_config('ceph-fs-uuid', %x[uuidgen -r].strip)
        make_config('ceph-mon-key', ceph_keygen)
    end
end

ruby_block 'write-ceph-mon-key' do
    block do
        %x[ ceph-authtool "/etc/ceph/ceph.mon.keyring" \
                --create-keyring \
                --name=mon. \
                --add-key="#{get_config('ceph-mon-key')}" \
                --cap mon 'allow *'
        ]
    end
    not_if "test -f /etc/ceph/ceph.mon.keyring"
end

template '/etc/ceph/ceph.conf' do
    source 'ceph.conf.erb'
    mode '0644'
    variables(:servers => get_head_nodes)
end

bcpc_cephconfig 'paxos_propose_interval' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "60" : "1"
  target "ceph-*"
end

bcpc_cephconfig 'osd_recovery_max_active' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "15"
  target "ceph-*"
end

bcpc_cephconfig 'osd_max_backfills' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "10"
  target "ceph-*"
end

bcpc_cephconfig 'osd_op_threads' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "10" : "2"
  target "ceph-*"
end

bcpc_cephconfig 'osd_recovery_op_priority' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "1" : "10"
  target "ceph-*"
end

bcpc_cephconfig 'osd_mon_report_interval_min' do  
  value node["bcpc"]["ceph"]["rebalance"] ? "30" : "5"
  target "ceph-*"
end

bash "wait-for-pgs-creating" do
    action :nothing
    user "root"
    code "sleep 1; while ceph -s | grep -v mdsmap | grep creating >/dev/null 2>&1; do echo Waiting for new pgs to create...; sleep 1; done"
end
