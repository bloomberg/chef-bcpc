#
# Cookbook Name:: bcpc_common
# Recipe:: common_packages
#
# Copyright 2016, Bloomberg Finance L.P.
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

# Remove backports repository if configured to avoid its treachery
apt_repository 'backports' do
  action :remove
end

# configure dpkg to not complain about our managed config files
# (configured in two places to make really sure it happens)
cookbook_file '/etc/apt/apt.conf.d/01managed_config_files' do
  source 'common_packages/etc_apt_apt.conf.d_01managed_config_files'
  owner  'root'
  group  'root'
  mode   00644
end

cookbook_file '/etc/dpkg/dpkg.cfg.d/managed_config_files' do
  source 'common_packages/etc_dpkg_dpkg.cfg.d_managed_config_files'
  owner  'root'
  group  'root'
  mode   00644
end

# packages to add to all systems
(
  node['bcpc_common']['packages']['convenience'] +
  node['bcpc_common']['packages']['net_troubleshooting'] +
  node['bcpc_common']['packages']['io_troubleshooting'] +
  node['bcpc_common']['packages']['sys_troubleshooting'] +
  ["linux-tools-#{node['kernel']['release']}"]
).each do |pkg|
  package pkg do
    action :upgrade
  end
end

# remove from all systems
node['bcpc_common']['packages']['to_remove'].each do |pkg|
  package pkg do
    action :remove
  end
end
