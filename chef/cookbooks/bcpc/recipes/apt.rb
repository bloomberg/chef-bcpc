# Cookbook:: bcpc
# Recipe:: apt
#
# Copyright:: 2019 Bloomberg Finance L.P.
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

file '/etc/apt/sources.list' do
  action :delete
end

bash 'remove-foreign-arch' do
  code 'dpkg --remove-architecture i386'
  only_if 'dpkg --print-foreign-architectures | grep i386'
end

repo = node['bcpc']['ubuntu']['repo']
codename = node['lsb']['codename']

# main ubuntu-archive repository
apt_repository 'ubuntu-archive' do
  uri repo['archive_url']
  distribution codename
  components repo['components']
  key repo['key']
end

# other ubuntu-archive repositories
distributions = %w(updates backports)
distributions.each do |dist|
  apt_repository "ubuntu-archive-#{dist}" do
    uri repo['archive_url']
    distribution "#{codename}-#{dist}"
    components repo['components']
    key repo['key']
  end
end

# security ubuntu-archive repository
apt_repository 'security-ubuntu-archive' do
  uri repo['security_url']
  distribution "#{codename}-security"
  components repo['components']
  key repo['key']
end
