#
# Cookbook Name:: bcpc
# Recipe:: contrail-work
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

include_recipe "bcpc::contrail-common"

%w{ contrail-nova-driver
    contrail-vrouter-dkms
    contrail-vrouter-agent
    contrail-vrouter-utils
    python-contrail-vrouter-api
}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

bash "enable-vrouter" do
    user "root"
    code <<-EOH
        modprobe vrouter
        sed --in-place '/^vrouter$/d' /etc/modules
        echo 'vrouter' >> /etc/modules
    EOH
    not_if "grep -e '^vrouter$' /etc/modules"
end

template "/etc/network/interfaces.d/iface-vhost0" do
    source "network.vhost.erb"
    owner "root"
    group "root"
    mode 00644
    variables(
        :interface => node['bcpc']['floating']['interface'],
        :ip => node['bcpc']['floating']['ip'],
        :netmask => node['bcpc']['floating']['netmask'],
        :gateway => node['bcpc']['floating']['gateway']
    )
end

bash "vhost0-up" do
    user "root"
    code "ifup vhost0"
    not_if "ip link show up | grep vhost0"
end

template "/etc/contrail/contrail-vrouter-agent.conf" do
    source "contrail-vrouter-agent.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00644
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-vrouter-agent]", :immediately
end

%w{ contrail-vrouter-agent }.each do |pkg|
    service pkg do
        action [:enable, :start]
    end
end
