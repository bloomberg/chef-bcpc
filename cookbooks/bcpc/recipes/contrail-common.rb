#
# Cookbook Name:: bcpc
# Recipe:: contrail-common
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

include_recipe "bcpc::openstack"

apt_repository "contrail" do
    uri node['bcpc']['repos']['contrail']
    distribution node['lsb']['codename']
    components ["main"]
    key "contrail.key"
end

template "/usr/local/bin/hup_contrail" do
    source "hup_contrail.erb"
    mode 0755
    owner "root"
    group "root"
    variables(:servers => get_head_nodes)
end
