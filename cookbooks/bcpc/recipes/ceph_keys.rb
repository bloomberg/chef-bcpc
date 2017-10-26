#
# Cookbook Name:: bcpc
# Recipe:: ceph_keys
#
# Copyright 2017, Bloomberg Finance L.P.
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

ruby_block 'initialize-ceph-keys' do
  block do
    make_config('ceph-fs-uuid', `uuidgen -r`.strip)
    make_config('ceph-mon-key', ceph_keygen)
    make_config('ceph-bootstrap-osd-key', ceph_keygen)
  end
end

directory '/etc/ceph' do
  owner 'ceph'
  group 'ceph'
end

ruby_block 'initialize-ceph-mon-keyring' do
  block do
    cmd = Mixlib::ShellOut.new(
      "ceph-authtool /etc/ceph/ceph.mon.keyring \
       --create-keyring \
       --add-key #{get_config('ceph-mon-key')} \
       --name mon. \
       --cap mon 'allow *'",
      user: 'ceph'
    )
    cmd.run_command
    cmd.stdout
    cmd.error!
  end
  not_if {
    system "ceph-authtool /etc/ceph/ceph.mon.keyring -l \
            >/dev/null 2>&1"
  }
end

ruby_block 'initialize-ceph-admin-keyring' do
  block do
    cmd = Mixlib::ShellOut.new(
      "ceph-authtool /etc/ceph/ceph.client.admin.keyring \
       --create-keyring \
       --add-key #{get_config('ceph-mon-key')} \
       --name client.admin --set-uid=0 \
       --cap mgr 'allow *' \
       --cap mon 'allow *' \
       --cap osd 'allow *'",
      user: 'ceph'
    )
    cmd.run_command
    cmd.stdout
    cmd.error!
  end
  not_if {
    system "ceph-authtool /etc/ceph/ceph.client.admin.keyring -l \
            >/dev/null 2>&1"
  }
end

ruby_block 'initialize-ceph-bootstrap-keyring' do
  block do
    cmd = Mixlib::ShellOut.new(
      "ceph-authtool /etc/ceph/ceph.client.bootstrap-osd.keyring \
       --create-keyring \
       --add-key #{get_config('ceph-bootstrap-osd-key')} \
       --name client.bootstrap-osd \
       --cap mon 'profile bootstrap-osd'",
      user: 'ceph'
    )
    cmd.run_command
    cmd.stdout
    cmd.error!
  end
  not_if {
    system "ceph-authtool /etc/ceph/ceph.client.bootstrap-osd.keyring -l \
            >/dev/null 2>&1"
  }
end

%w[client.admin client.bootstrap-osd].each do |keyring|
  bash "import-#{keyring}-keyring" do
    user 'ceph'
    code <<-EOH
      ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring \
      /etc/ceph/ceph.#{keyring}.keyring
    EOH
  end
end
