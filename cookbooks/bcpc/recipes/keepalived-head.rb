#
# Cookbook Name:: bcpc
# Recipe:: keepalived-head
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

include_recipe "bcpc::default"
include_recipe "bcpc::keepalived-common"

ruby_block "initialize-keepalived-config" do
    block do
        make_config('keepalived-router-id', generate_vrrp_vrid)
        make_config('keepalived-password', secure_password)
    end
end

%w{if_vip if_not_vip vip_change vip_won vip_lost}.each do |script|
    template "/usr/local/bin/#{script}" do
        source "keepalived-#{script}.erb"
        mode 0755
        owner "root"
        group "root"
    end
end

template "/etc/keepalived/keepalived.conf" do
    source "keepalived-head.conf.erb"
    mode 00644
    notifies :restart, "service[keepalived]", :immediately
end
