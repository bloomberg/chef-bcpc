# Cookbook Name:: bcpc
# Recipe:: apt
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

template '/etc/apt/apt.conf.d/00bcpc' do
  source 'apt/bcpc-apt.conf.erb'
  variables(
    conf: node['bcpc']['apt']
  )
end

file '/etc/apt/sources.list' do
  action :delete
end

arch = node['bcpc']['ubuntu']['arch']
codename = node['lsb']['codename']

# main ubuntu-archive repository
apt_repository 'ubuntu-archive' do
  arch arch
  uri node['bcpc']['ubuntu']['archive_url']
  distribution codename
  components node['bcpc']['ubuntu']['components']
end

# other ubuntu-archive repositories
distributions = %w(updates backports)
distributions.each do |dist|
  apt_repository "ubuntu-archive-#{dist}" do
    arch arch
    uri node['bcpc']['ubuntu']['archive_url']
    distribution "#{codename}-#{dist}"
    components node['bcpc']['ubuntu']['components']
  end
end

# security ubuntu-archive repository
apt_repository 'security-ubuntu-archive' do
  arch arch
  uri node['bcpc']['ubuntu']['security_url']
  distribution "#{codename}-security"
  components node['bcpc']['ubuntu']['components']
end
