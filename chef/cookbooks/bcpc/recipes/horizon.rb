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

region = node['bcpc']['cloud']['region']
config = data_bag_item(region, 'config')

package 'openstack-dashboard'

service 'horizon' do
  service_name 'apache2'
end

# options specified to keep dpkg from complaining that the config file exists already
package 'openstack-dashboard' do
  action :install
  notifies :run, 'bash[dpkg-reconfigure-openstack-dashboard]', :delayed
  notifies :run, 'bash[clean-old-dashboard-pyc-files]', :immediately
end

template '/etc/openstack-dashboard/local_settings.py' do
  source 'horizon/local_settings.py.erb'
  variables(
    region: region,
    config: config,
    headnodes: headnodes(all: true)
  )
  notifies :restart, 'service[horizon]', :delayed
end
