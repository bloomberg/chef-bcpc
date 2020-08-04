# Cookbook:: bcpc
# Recipe:: nova-compute
#
# Copyright:: 2020 Bloomberg Finance L.P.
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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')
zone_config = ZoneConfig.new(node, region, method(:data_bag_item))
nova_compute_config = zone_config.nova_compute_config

database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['nova']['db']['dbname'],
  'username' => config['nova']['creds']['db']['username'],
  'password' => config['nova']['creds']['db']['password'],
}

package %w(
  ceph
  nova-compute
  nova-api-metadata
  ovmf
  pm-utils
  sysfsutils
)

service 'nova-compute'
service 'nova-api-metadata'
service 'libvirtd'

# configure nova user starts
user 'nova' do
  shell '/bin/bash'
end

directory '/var/lib/nova/.ssh' do
  mode '700'
  owner 'nova'
  group 'nova'
end

begin
  nova_authkeys = []
  nova_authkeys.push(Base64.decode64(config['nova']['ssh']['crt']).to_s)
  # add roots public key for live migrations via libvirts qemu+ssh
  nova_authkeys.push(Base64.decode64(config['ssh']['public']).to_s)

  file '/var/lib/nova/.ssh/authorized_keys' do
    content nova_authkeys.join("\n")
    mode '644'
    owner 'nova'
    group 'nova'
  end
end

file '/var/lib/nova/.ssh/id_ed25519' do
  content Base64.decode64(config['nova']['ssh']['key']).to_s
  mode '600'
  owner 'nova'
  group 'nova'
end

cookbook_file '/var/lib/nova/.ssh/config' do
  source 'nova/ssh-config'
  mode '600'
  owner 'nova'
  group 'nova'
end

host_uuid = ''
ruby_block 'generate host uuid' do
  block do
    Chef::Resource::RubyBlock.include Chef::Mixin::ShellOut
    cmd = "uuidgen --md5 --name #{node['fqdn']} --namespace @dns"
    cmd = shell_out(cmd)
    host_uuid = cmd.stdout.chomp()
  end
end

# if this node is a worknode and storage node then we want the storage node
# ceph recipe to takes precedence (ie: this block won't execute)
unless storagenode?
  rbd_users = []
  rbd_users.append(nova_compute_config.ceph_user)

  template '/etc/ceph/ceph.conf' do
    source 'ceph/ceph.conf.erb'
    variables(
      config: config,
      headnodes: headnodes,
      public_network: primary_network_aggregate_cidr,
      rbd_users: rbd_users
    )
  end
end

# install ceph keys
file "/etc/ceph/ceph.client.#{nova_compute_config.ceph_user}.keyring" do
  content "[client.#{nova_compute_config.ceph_user}]\n\tkey = #{nova_compute_config.ceph_key}\n"
  mode '0640'
  group 'libvirt'
end

# configure libvirt
template '/etc/libvirt/libvirtd.conf' do
  source 'libvirt/libvirtd.conf.erb'
  variables(
    host_uuid: lazy { host_uuid }
  )
  notifies :restart, 'service[libvirtd]', :immediately
end

cookbook_file '/etc/libvirt/qemu.conf' do
  source 'libvirt/qemu.conf'
  notifies :restart, 'service[libvirtd]', :immediately
end

template '/etc/nova/virsh-secret.xml' do
  source 'nova/virsh-secret.xml.erb'

  variables(
    ceph_user: nova_compute_config.ceph_user,
    libvirt_secret: nova_compute_config.libvirt_secret
  )

  notifies :run, 'bash[load virsh secrets]', :immediately
  not_if "virsh secret-list | grep -i #{nova_compute_config.libvirt_secret}"
end

bash 'load virsh secrets' do
  action :nothing

  code <<-DOC
    virsh secret-define --file /etc/nova/virsh-secret.xml
    virsh secret-set-value \
      --secret #{nova_compute_config.libvirt_secret} \
      --base64 #{nova_compute_config.ceph_key}
  DOC

  notifies :restart, 'service[libvirtd]', :immediately
end

bash 'remove default virsh net' do
  code <<-DOC
    virsh net-destroy default
    virsh net-undefine default
  DOC
  only_if 'virsh net-list | grep -i default'
end

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end

directory '/etc/systemd/system/nova-api-metadata.service.d' do
  action :create
end

# Work-around so that nova-api-metadata waits for systemd-resolved to
# become online. This is necessary because eventlet's underlying resolver
# library defaults to a stub configuration that is incorrect at boot and
# the daemon never sees the updated configuration.
cookbook_file '/etc/systemd/system/nova-api-metadata.service.d/custom.conf' do
  source 'nova/custom.conf'
  notifies :run, 'execute[reload systemd]', :immediately
end

template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'
  variables(
    db: database,
    config: config,
    headnodes: headnodes,
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :restart, 'service[nova-compute]', :immediately
  notifies :restart, 'service[nova-api-metadata]', :immediately
end

template '/etc/nova/nova-compute.conf' do
  source 'nova/nova-compute.conf.erb'

  variables(
    virt_type: node['cpu']['0']['flags'].include?('vmx') ? 'kvm' : 'qemu',
    images_rbd_pool: nova_compute_config.ceph_pool,
    rbd_user: nova_compute_config.ceph_user,
    rbd_secret_uuid: nova_compute_config.libvirt_secret
  )

  notifies :restart, 'service[libvirtd]', :immediately
  notifies :restart, 'service[nova-compute]', :immediately
end

execute 'wait for compute host' do
  environment os_adminrc
  retries 15
  command <<-DOC
    openstack compute service list \
      --service nova-compute | grep #{node['hostname']}
  DOC
end
