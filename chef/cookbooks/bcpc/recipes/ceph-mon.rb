# Cookbook:: bcpc
# Recipe:: ceph-mon
#
# Copyright:: 2021 Bloomberg Finance L.P.
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

return unless node['bcpc']['ceph']['mon']['enabled']

include_recipe 'bcpc::ceph-packages'

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

service "ceph-mon@#{node['hostname']}"

template '/etc/ceph/ceph.client.admin.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  mode '0640'
  variables(
    username: 'admin',
    client: config['ceph']['client']['admin'],
    caps: [
      'caps mds = "allow *"',
      'caps mgr = "allow *"',
      'caps mon = "allow *"',
      'caps osd = "allow *"',
    ]
  )
end

template '/etc/ceph/ceph.bootstrap-mgr.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-mgr',
    client: config['ceph']['bootstrap']['mgr'],
    caps: ['caps mon = "allow profile bootstrap-mgr"']
  )
end

template '/etc/ceph/ceph.bootstrap-osd.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-osd',
    client: config['ceph']['bootstrap']['osd'],
    caps: ['caps mon = "allow profile bootstrap-osd"']
  )
end

template '/etc/ceph/ceph.bootstrap-mds.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-mds',
    client: config['ceph']['bootstrap']['mds'],
    caps: ['caps mon = "allow profile bootstrap-mds"']
  )
end

template '/etc/ceph/ceph.bootstrap-rgw.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-rgw',
    client: config['ceph']['bootstrap']['rgw'],
    caps: ['caps mon = "allow profile bootstrap-rgw"']
  )
end

template '/etc/ceph/ceph.bootstrap-rbd.keyring' do
  source 'ceph/ceph.client.keyring.erb'
  variables(
    username: 'bootstrap-rbd',
    client: config['ceph']['bootstrap']['rbd'],
    caps: ['caps mon = "allow profile bootstrap-rbd"']
  )
end

template '/etc/ceph/ceph.mon.keyring' do
  source 'ceph/ceph.mon.keyring.erb'
  variables(
    key: config['ceph']['mon']['key']
  )
end

rbd_users = []

# If this node is an OpenStack headnode and a storage headnode, then this
# recipe is responsible for rendering the Ceph configuration file and
# appending the Glance Ceph user to the list of rbd_users.
if headnode?
  rbd_users.append('glance')
end

template '/etc/ceph/ceph.conf' do
  source 'ceph/ceph.conf.erb'

  variables(
    config: config,
    storageheadnodes: init_storage? ? [node] : storageheadnodes,
    public_network: primary_network_aggregate_cidr,
    rbd_users: rbd_users
  )
  notifies :restart, "service[ceph-mon@#{node['hostname']}]", :immediately
end

directory '/usr/local/bcpc/bin' do
  recursive true
end

template '/usr/local/bcpc/bin/if_ceph_leader' do
  source 'ceph/if_ceph_leader.erb'
  mode '0755'
end

begin
  if init_storage?

    execute 'create ceph cluster' do
      cwd '/etc/ceph'

      command 'ceph-deploy mon create-initial'
      creates "/var/lib/ceph/mon/ceph-#{node['hostname']}/done"

      notifies :run, 'bash[copy client keyrings to tmp dir]', :before
      notifies :run, 'bash[import client keyrings]', :immediately
    end

    bash 'copy client keyrings to tmp dir' do
      action :nothing
      cwd '/etc/ceph'
      code <<-DOC
        tmp_dir='.tmp'
        rm -rf ${tmp_dir}
        mkdir ${tmp_dir}
        cp *.keyring ${tmp_dir}
      DOC
    end

    bash 'import client keyrings' do
      action :nothing
      cwd '/etc/ceph'
      code <<-DOC
        tmp_dir='.tmp'

        # import the client.admin keyring first and move it to /etc/ceph
        #
        ceph auth import -i ${tmp_dir}/ceph.client.admin.keyring
        chmod 0640 ${tmp_dir}/ceph.client.admin.keyring
        mv ${tmp_dir}/ceph.client.admin.keyring /etc/ceph

        for keyring in ${tmp_dir}/*.keyring; do
          ceph auth import -i ${keyring}
          mv ${keyring} /etc/ceph/
        done

        rm -rf ${tmp_dir}
      DOC
    end
  else

    execute 'join ceph cluster' do
      cwd '/etc/ceph'
      command "ceph-deploy mon add #{node['hostname']}"
      creates "/var/lib/ceph/mon/ceph-#{node['hostname']}/done"
    end
  end
end

ceph_racks.each do |rack|
  bash "create ceph #{rack} rack bucket" do
    code <<-EOH
      ceph osd crush add-bucket #{rack} rack
      ceph osd crush move #{rack} root=default
    EOH
    not_if "ceph osd tree | grep #{rack}"
  end
end
