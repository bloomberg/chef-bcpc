#
# Cookbook Name:: bcpc
# Recipe:: packages_ceph
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

include_recipe 'bcpc::packages-openstack'

apt_repository 'ceph' do
  uri node['bcpc']['repos']['ceph']
  distribution node['lsb']['codename']
  components ['main']
  key 'ceph-release.key'
end

# configure an apt preference to prefer Luminous packages
apt_preference 'ceph' do
  glob 'python-rbd python-rados python-ceph librbd1 libradosstriper1 librados2 ceph-common ceph'
  pin 'version 12.2.2-1xenial'
  pin_priority '900'
end

%w[librados2 librbd1 python-ceph ceph ceph-common].each do |pkg|
  package pkg do
    action :upgrade
  end
end

# as of xenial, ntp has been superseded by timesyncd for time synchronization.
# the ceph-base package, which is depended on by the ceph package, has a
# recommended dependency on the ntp package which apt has been configured
# to follow. instead of changing that behaviour to prevent the ntp package
# from installing, it seems cleaner to just purge the package from the system
# if it happens to sneak its way in. we also want to kick timesyncd incase
# the installation of ntp caused the systemd FailedCondition to trigger
#
package 'ntp' do
  action :purge
  notifies :restart, 'service[systemd-timesyncd]', :immediately
end
