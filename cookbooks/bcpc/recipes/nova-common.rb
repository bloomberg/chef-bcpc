#
# Cookbook Name:: bcpc
# Recipe:: nova-common
#
# Copyright 2013, Bloomberg L.P.
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

include_recipe "bcpc::default"
include_recipe "bcpc::openstack"

ruby_block "initialize-nova-config" do
    block do
        make_config('mysql-nova-user', "nova")
        make_config('mysql-nova-password', secure_password)
        make_config('glance-cloudpipe-uuid', %x[uuidgen -r].strip)
    end
end

template "/etc/nova/nova.conf" do
    source "nova.conf.erb"
    owner "nova"
    group "nova"
    mode 00600
    variables( :servers => get_head_nodes )
end

template "/etc/nova/api-paste.ini" do
    source "nova.api-paste.ini.erb"
    owner "nova"
    group "nova"
    mode 00600
end

template "/usr/local/bin/hup_openstack" do
    source "hup_openstack.erb"
    mode 0755
    owner "root"
    group "root"
end
