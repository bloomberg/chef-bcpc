# Cookbook:: bcpc
# Recipe:: percona-apt
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

# Define the Percona repository to use
repo = node['bcpc']['percona']['repo']
tools_repo = node['bcpc']['percona-tools']['repo']
codename = node['lsb']['codename']

# Add the specified repository
apt_repository 'percona' do
  uri repo['url']
  distribution codename
  components ['main']
  key repo['key']
  only_if { repo['enabled'] }
end

apt_repository 'percona-tools' do
  uri tools_repo['url']
  distribution codename
  components ['main']
  key tools_repo['key']
  only_if { tools_repo['enabled'] }
end
