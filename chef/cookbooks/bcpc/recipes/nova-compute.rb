# Cookbook Name:: bcpc
# Recipe:: nova-work
#
# Copyright 2018, Bloomberg Finance L.P.
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

database = {
  'host' => node['bcpc']['mysql']['host'],
  'dbname' => node['bcpc']['nova']['db']['dbname'],
  'username' => config['nova']['creds']['db']['username'],
  'password' => config['nova']['creds']['db']['password'],
}

package 'nova-compute'
package 'nova-api-metadata'
package 'pm-utils'
package 'memcached'
package 'sysfsutils'

service 'nova-compute'
service 'nova-api-metadata'
service 'libvirtd'

# configure nova user starts
user 'nova' do
  shell '/bin/bash'
end

# add the nova user to the ceph group so nova can read
# cinders ceph client key file
#
group 'ceph' do
  action :modify
  append true
  members 'nova'
end

directory '/var/lib/nova/.ssh' do
  mode '700'
  owner 'nova'
  group 'nova'
end

file '/var/lib/nova/.ssh/authorized_keys' do
  content Base64.decode64(config['nova']['ssh']['crt']).to_s
  mode '644'
  owner 'nova'
  group 'nova'
end

file '/var/lib/nova/.ssh/id_rsa' do
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

# configure libvirt
template '/etc/libvirt/libvirtd.conf' do
  source 'libvirt/libvirtd.conf.erb'
  notifies :restart, 'service[libvirtd]', :immediately
end

cookbook_file '/etc/default/libvirtd' do
  source 'libvirt/default'
  notifies :restart, 'service[libvirtd]', :immediately
end

cookbook_file '/etc/libvirt/qemu.conf' do
  source 'libvirt/qemu.conf'
  notifies :restart, 'service[libvirtd]', :immediately
end

execute 'export client.cinder ceph keyring' do
  user 'root'
  group 'ceph'
  command 'ceph auth get client.cinder -o /etc/ceph/ceph.client.cinder.keyring'
end

template '/etc/nova/virsh-secret.xml' do
  source 'nova/virsh-secret.xml.erb'

  variables(
    config: config
  )

  notifies :run, 'bash[load virsh secrets]', :immediately
  not_if "virsh secret-list | grep -i #{config['libvirt']['secret']}"
end

bash 'load virsh secrets' do
  action :nothing

  code <<-DOC
    virsh secret-define --file /etc/nova/virsh-secret.xml
    virsh secret-set-value \
      --secret #{config['libvirt']['secret']} \
      --base64 $(ceph auth get-key client.cinder)
  DOC
end

bash 'remove default virsh net' do
  code <<-DOC
    virsh net-destroy default
    virsh net-undefine default
  DOC
  only_if 'virsh net-list | grep -i default'
end

template '/etc/nova/nova.conf' do
  source 'nova/nova.conf.erb'
  variables(
    db: database,
    config: config,
    headnodes: headnodes,
    vip: get_address(node['bcpc']['cloud']['vip']['ip'])
  )
  notifies :restart, 'service[nova-compute]', :immediately
end

template '/etc/nova/nova-compute.conf' do
  source 'nova/nova-compute.conf.erb'

  variables(
    config: config,
    virt_type: node['cpu']['0']['flags'].include?('vmx') ? 'kvm' : 'qemu'
  )

  notifies :restart, 'service[nova-compute]', :immediately
  notifies :restart, 'service[nova-api-metadata]', :immediately
end

execute 'wait for compute host' do
  environment os_adminrc
  retries 15
  command <<-DOC
    openstack compute service list \
      --service nova-compute | grep #{node['hostname']}
  DOC
end

begin
  az = local_availability_zone

  execute "add #{node['hostname']} to the #{az} availability zone" do
    environment os_adminrc
    command "openstack aggregate add host #{az} #{node['hostname']}"
    not_if "
      agg=$(openstack aggregate show #{az} -f value -c hosts)
      echo ${agg} | grep -w #{node['hostname']}
    "
  end
end
