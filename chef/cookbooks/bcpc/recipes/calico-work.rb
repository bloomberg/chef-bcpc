# Cookbook:: bcpc
# Recipe:: calico-work
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

include_recipe 'bcpc::etcd3gw'
include_recipe 'bcpc::calico-apt'

package %w(
  calico-compute
  calico-dhcp-agent
) do
  action :upgrade
end

service 'calico-dhcp-agent'

execute 'reload systemd' do
  action :nothing
  command 'systemctl daemon-reload'
end

cookbook_file '/etc/systemd/system/calico-dhcp-agent.service.d/custom.conf' do
  action :delete
  notifies :run, 'execute[reload systemd]', :immediately
end

directory '/etc/systemd/system/calico-dhcp-agent.service.d' do
  action :delete
end

# these neutron services are installed/enabled by calico packages
# these services are superseded by nova-metadata-agent and calico-dhcp-agent
# so we don't need them to be enabled/running
%w(neutron-dhcp-agent neutron-metadata-agent).each do |srv|
  service srv do
    action %i(disable stop)
  end
end

# patch an outstanding python3 issue in etcd3gw
# we do this here and not in bcpc::etcd3gw so we can notify calico-dhcp-agent
if platform?('ubuntu')
  if node['platform_version'] == '18.04'
    dist_packages = '/usr/lib/python3.6/dist-packages'
    cookbook_file '/usr/local/lib/python3.6/dist-packages/etcd3gw/watch.py' do
      source 'etcd3gw/watch.py'
      notifies :restart, 'service[calico-dhcp-agent]', :delayed
    end
  elsif node['platform_version'] == '20.04'
    dist_packages = '/usr/lib/python3.8/dist-packages'
  end
end

cookbook_file "#{dist_packages}/networking_calico/agent/linux/dhcp.py" do
  source 'calico/dhcp.py'
  notifies :restart, 'service[calico-dhcp-agent]', :delayed
end

template '/etc/neutron/neutron.conf' do
  source 'calico/neutron.conf.erb'
  mode '644'
  owner 'root'
  group 'neutron'
  notifies :restart, 'service[calico-dhcp-agent]', :immediately
end
