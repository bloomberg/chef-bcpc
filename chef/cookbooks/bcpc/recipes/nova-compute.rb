# Cookbook:: bcpc
# Recipe:: nova-compute
#
# Copyright:: 2023 Bloomberg Finance L.P.
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

db_conn = db_conn()

# hash used for database creation and access
#
database = {
  'host' => db_conn['host'],
  'port' => db_conn['port'],
  'dbname' => node['bcpc']['nova']['db']['dbname'],
  'username' => config['nova']['creds']['db']['username'],
  'password' => config['nova']['creds']['db']['password'],
}

package %w(
  ceph
  nova-compute
  libvirt-daemon-driver-storage-rbd
  nova-api-metadata
  ovmf
  pm-utils
  qemu-block-extra
  sysfsutils
) do
  options '--no-install-recommends'
end

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
      is_bootstrapping: false,
      storageheadnodes: storageheadnodes,
      public_network: primary_network_aggregate_cidr,
      rbd_users: rbd_users
    )
    notifies :restart, 'service[nova-compute]', :immediately
  end
end

if zone_config.alternate_backends_enabled?
  cookbook_file '/usr/lib/python3/dist-packages/os_brick/initiator/connectors/lightos.py' do
    source 'cinder/lightos_connector.py'
    notifies :run, 'execute[py3compile-os-brick]', :immediately
    notifies :restart, 'service[nova-compute]', :delayed
  end

  execute 'py3compile-os-brick' do
    action :nothing
    command 'py3compile -p python3-os-brick'
  end
end

# create hypervisor-specific client.*cinder Ceph keyring
template "/etc/ceph/ceph.client.#{nova_compute_config.ceph_user}.keyring" do
  source 'nova/ceph.client.nova.keyring.erb'

  mode '0640'
  owner 'root'
  group 'libvirt'

  variables(
    client: nova_compute_config.ceph_user,
    key: nova_compute_config.ceph_key
  )
end

# configure libvirt
cookbook_file '/etc/default/libvirtd' do
  source 'libvirt/libvirtd.default'
  notifies :restart, 'service[libvirtd]', :delayed
end

template '/etc/libvirt/libvirtd.conf' do
  source 'libvirt/libvirtd.conf.erb'
  variables(
    host_uuid: lazy { host_uuid }
  )
  notifies :restart, 'service[libvirtd]', :immediately
end

template '/etc/libvirt/qemu.conf' do
  source 'libvirt/qemu.conf.erb'
  variables(
    max_files: node['bcpc']['qemu']['max_files'],
    max_processes: node['bcpc']['qemu']['max_processes']
  )
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

# Deliver a manifest for Cascade Lake that excludes the `mpx` feature so
# that later processor families that lack the feature, such as Ice Lake,
# can still support a Cascade Lake CPU baseline.
# https://gitlab.com/libvirt/libvirt/-/issues/304
cookbook_file '/usr/share/libvirt/cpu_map/x86_Cascadelake-Server.xml' do
  source 'libvirt/x86_Cascadelake-Server.xml'
  notifies :restart, 'service[libvirtd]', :delayed
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
  mode '0640'
  owner 'root'
  group 'nova'

  variables(
    db: database,
    config: config,
    headnodes: headnodes,
    rmqnodes: rmqnodes,
    vip: node['bcpc']['cloud']['vip']
  )
  notifies :restart, 'service[nova-compute]', :immediately
  notifies :restart, 'service[nova-api-metadata]', :delayed
end

flags = node['cpu']['0']['flags'] & %w(svm vmx)
virt_type = flags.empty? ? 'qemu' : 'kvm'
vendor_id = node['cpu']['0']['vendor_id']
cpu_config = node['bcpc']['nova']['cpu_config'][vendor_id]

template '/etc/nova/nova-compute.conf' do
  source 'nova/nova-compute.conf.erb'
  mode '0640'
  owner 'root'
  group 'nova'

  variables(
    virt_type: virt_type,
    cpu_mode: cpu_config['cpu_mode'],
    cpu_model: cpu_config['cpu_model'],
    cpu_model_extra_flag: cpu_config['cpu_model_extra_flags'],
    images_rbd_pool: nova_compute_config.ceph_pool,
    rbd_user: nova_compute_config.ceph_user,
    rbd_secret_uuid: nova_compute_config.libvirt_secret
  )

  notifies :restart, 'service[libvirtd]', :immediately
  notifies :restart, 'service[nova-compute]', :immediately
end

# Ensure that the MTU is not changed during a live-migration
# https://bugs.launchpad.net/nova/+bug/1984009
#
# Also backport a bug stemming from a libvirt change:
# https://bugs.launchpad.net/nova/+bug/1978489
cookbook_file '/usr/lib/python3/dist-packages/nova/virt/libvirt/migration.py' do
  source 'nova/migration.py'
  notifies :run, 'execute[py3compile-nova]', :immediately
  notifies :restart, 'service[nova-compute]', :delayed
end

cookbook_file '/usr/lib/python3/dist-packages/nova/virt/libvirt/driver.py' do
  source "nova/driver_#{node['platform_version']}.py"
  notifies :run, 'execute[py3compile-nova]', :immediately
  notifies :restart, 'service[nova-compute]', :delayed
end

# (rendition of): https://review.opendev.org/c/openstack/nova/+/852002
# Fixed in qemu as of 1:4.2-3ubuntu6.25 in Focal, 1:6.2+dfsg-2ubuntu6.7 in Jammy
if node['platform_version'] == '20.04'
  cookbook_file '/usr/lib/python3/dist-packages/nova/virt/libvirt/guest.py' do
    source 'nova/guest.py'
    notifies :run, 'execute[py3compile-nova]', :immediately
    notifies :restart, 'service[nova-compute]', :delayed
  end
end

execute 'py3compile-nova' do
  action :nothing
  command 'py3compile -p python3-nova'
end

execute 'wait for compute host' do
  environment os_adminrc
  retries 15
  command <<-DOC
    openstack compute service list \
      --service nova-compute | grep #{node['hostname']}
  DOC
end
