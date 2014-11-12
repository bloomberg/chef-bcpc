#
# Cookbook Name:: bcpc
# Recipe:: haproxy
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

ruby_block "initialize-haproxy-config" do
    block do
        make_config('haproxy-stats-user', "haproxy")
        make_config('haproxy-stats-password', secure_password)
    end
end

apt_repository "haproxy" do
    uri node['bcpc']['repos']['haproxy']
    distribution node['lsb']['codename']
    components ["main"]
    key "haproxy.key"
end

package "haproxy" do
    action :upgrade
end

bash "enable-defaults-haproxy" do
    user "root"
    code <<-EOH
        sed --in-place '/^ENABLED=/d' /etc/default/haproxy
        echo 'ENABLED=1' >> /etc/default/haproxy
    EOH
    not_if "grep -e '^ENABLED=1' /etc/default/haproxy"
end

template "/etc/haproxy/haproxy.pem" do
    source "haproxy.pem.erb"
    owner "root"
    group "root"
    mode 00600
    notifies :restart, "service[haproxy]", :delayed
end

template "/etc/haproxy/haproxy.cfg" do
    source "haproxy.cfg.erb"
    mode 00644
    variables(
        :servers => get_head_nodes,
        :all_servers => get_ceph_osd_nodes
    )
    notifies :restart, "service[haproxy]", :immediately
end

service "haproxy" do
    restart_command "service haproxy stop && service haproxy start && sleep 5"
    action [:enable, :start]
end
