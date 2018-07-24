#
# Cookbook Name:: bcpc
# Recipe:: horizon
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
#
make_config('horizon-secret-key', secure_password)

package 'openstack-dashboard'

service 'horizon' do
  service_name 'apache2'
end

# options specified to keep dpkg from complaining that the config file exists already
package "openstack-dashboard" do
  action :install
  notifies :run, "bash[dpkg-reconfigure-openstack-dashboard]", :delayed
  notifies :run, 'bash[clean-old-dashboard-pyc-files]', :immediately
end

template '/etc/openstack-dashboard/local_settings.py' do
  source 'horizon/local_settings.py.erb'
  variables(
    'servers' => get_head_nodes
  )
  notifies :restart, 'service[horizon]', :delayed
end

=begin

# this adds a way to override and customize Horizon's behavior
horizon_customize_dir = ::File.join('/', 'usr', 'local', 'bcpc-horizon', 'bcpc')
directory horizon_customize_dir do
  action    :create
  recursive true
end

file ::File.join(horizon_customize_dir, '__init__.py') do
  action :create
end

template ::File.join(horizon_customize_dir, 'overrides.py') do
  source   'horizon.overrides.py.erb'
  notifies :restart, 'service[apache2]', :delayed
end

horizon_policy_path = \
  '/usr/share/openstack-dashboard/openstack_dashboard/conf/'

%w[cinder glance heat keystone nova].each do |component|
  template horizon_policy_path + component + '_policy.json' do
    source "#{component}-policy.json.erb"
    owner 'root'
    group 'root'
    mode 00644
    variables('policy' =>
              JSON.pretty_generate(node['bcpc'][component]['policy']))
  end
end

# needed to regenerate the static assets for the dashboard
bash 'dpkg-reconfigure-openstack-dashboard' do
  action :nothing
  user 'root'
  code 'dpkg-reconfigure openstack-dashboard'
  notifies :restart, 'service[apache2]', :immediately
end

# troveclient gets installed by something and can blow up Horizon startup
# if not upgraded when moving from Kilo to Liberty
package 'python-troveclient' do
  action :install
  notifies :restart, "service[apache2]", :immediately
end

# we must patch the API access view to include the settings object so that
# API versions are accessible, if set explicitly in the Horizon config
# (only needed in Liberty, Mitaka has separate download links for each file)
bcpc_patch 'horizon-openrc-api-versions-liberty' do
  patch_file           'horizon-openrc-api-versions.patch'
  patch_root_dir       '/usr/share/openstack-dashboard'
  shasums_before_apply 'horizon-openrc-api-versions-BEFORE.SHASUMS'
  shasums_after_apply  'horizon-openrc-api-versions-AFTER.SHASUMS'
  notifies :restart, 'service[apache2]', :immediately
  only_if "dpkg --compare-versions $(dpkg -s openstack-dashboard | egrep '^Version:' | awk '{ print $NF }') ge 2:0 && dpkg --compare-versions $(dpkg -s openstack-dashboard | egrep '^Version:' | awk '{ print $NF }') lt 2:9"
end

# fix upstream bug 1593751 - broken LDAP groups in Horizon
bcpc_patch 'horizon-ldap-groups-mitaka' do
  patch_file           'horizon-ldap-groups.patch'
  patch_root_dir       '/usr/share/openstack-dashboard'
  shasums_before_apply 'horizon-ldap-groups-BEFORE.SHASUMS'
  shasums_after_apply  'horizon-ldap-groups-AFTER.SHASUMS'
  notifies :restart, 'service[apache2]', :delayed
  only_if "dpkg --compare-versions $(dpkg -s openstack-dashboard | egrep '^Version:' | awk '{ print $NF }') ge 2:0 && dpkg --compare-versions $(dpkg -s openstack-dashboard | egrep '^Version:' | awk '{ print $NF }') le 3:0"
end

# update openrc.sh template to provide additional environment variables and user domain
# for Liberty - for Mitaka, restore the original file
openrc_path = ::File.join(
  '/usr', 'share', 'openstack-dashboard', 'openstack_dashboard',
  'dashboards', 'project', 'access_and_security', 'templates',
  'access_and_security', 'api_access', 'openrc.sh.template')
cookbook_file openrc_path do
  source "horizon.#{node['bcpc']['openstack_release']}.openrc.sh.template"
  owner  'root'
  group  'root'
  mode   00644
end
