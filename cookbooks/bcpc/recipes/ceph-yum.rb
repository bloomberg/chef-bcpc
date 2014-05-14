#
# Cookbook Name:: bcpc
# Recipe:: ceph-yum
#
# Copyright 2013, Bloomberg Finance L.P.
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

cookbook_file "/etc/pki/rpm-gpg/ceph-release.key" do
  source "ceph-release.key"
  owner "root"
  group "root"
  mode 00644
end

# The YUM repositories for Ceph are wonky in that the repodata is per arch
# not per OS flavor.
yum_repository "ceph-x86_64" do
  description "Ceph repository"
  key "ceph-release.key"
  url node['bcpc']['repos']['ceph-el6-x86_64']
  action :add
end

yum_repository "ceph-noarch" do
  description "Ceph repository"
  key "ceph-release.key"
  url node['bcpc']['repos']['ceph-el6-noarch']
  action :add
end
