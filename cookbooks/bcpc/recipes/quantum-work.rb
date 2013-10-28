#
# Cookbook Name:: bcpc
# Recipe:: quantum-work
#
# Copyright 2013, PLUMgrid, http://plumgrid.com
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

include_recipe "bcpc::mysql"
include_recipe "bcpc::openstack"

# mysql user/pwd
ruby_block "initialize-quantum-config" do
    block do
        make_config('mysql-quantum-user', "quantum")
        make_config('mysql-quantum-password', secure_password)
    end
end

# configure plugin
case node['bcpc']['quantum']['core_plugin']
when "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
    %w{quantum-plugin-linuxbridge-agent}.each do |pkg|
        package pkg do
            action :upgrade
	end
	service pkg do
	    action [ :enable, :start ]
	end
    end
    template "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini" do
        source "linuxbridge_conf.ini.erb"
        owner "quantum"
        group "quantum"
        mode 00600
        notifies :run, "bash[restart-quantum-work]", :delayed
    end
end

# quantum config
template "/etc/quantum/quantum.conf" do
    source "quantum.conf.erb"
    owner "quantum"
    group "quantum"
    mode 00600
    notifies :run, "bash[restart-quantum-work]", :delayed
end

bash "restart-quantum-work" do
    case node['bcpc']['quantum']['core_plugin']
    when "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
        notifies :restart, "service[quantum-plugin-linuxbridge-agent]", :immediately
    end
end
