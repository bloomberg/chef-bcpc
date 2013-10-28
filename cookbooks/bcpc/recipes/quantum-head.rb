#
# Cookbook Name:: bcpc
# Recipe:: quantum-head
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

include_recipe "bcpc::quantum-work"
include_recipe "bcpc::mysql"
include_recipe "bcpc::openstack"


# common quantum packages
%w{quantum-server python-quantumclient quantum-metadata-agent}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

#common packages
%w{quantum-server quantum-metadata-agent}.each do |srv|
    service srv do
      provider Chef::Provider::Service::Upstart
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
    end
end

# plugin packages
case node['bcpc']['quantum']['core_plugin']
when "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
    %w{quantum-dhcp-agent quantum-l3-agent quantum-plugin-linuxbridge}.each do |pkg|
        package pkg do
            action :upgrade
        end
    end
    %w{quantum-dhcp-agent quantum-l3-agent}.each do |srv|
        service srv do
            provider Chef::Provider::Service::Upstart
        supports :status => true, :restart => true, :reload => true
        action [ :enable, :start ]
	end
    end
end

# quantum templates
template "/etc/quantum/quantum.conf" do
    source "quantum.conf.erb"
    owner "quantum"
    group "quantum"
    mode 00644
    notifies :run, "bash[restart-quantum-head]", :delayed
end

template "/etc/default/quantum-server" do
    source "quantum-server.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :run, "bash[restart-quantum-head]", :delayed
end

template "/etc/quantum/metadata_agent.ini" do
    source "metadata_agent.ini.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :run, "bash[restart-quantum-head]", :delayed
end

# plugin templates
case node['bcpc']['quantum']['core_plugin']
when "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
    template "/etc/quantum/dhcp_agent.ini" do
        source "dhcp_agent.ini.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :run, "bash[restart-quantum-head]", :delayed
   end
    template "/etc/quantum/dnsmasq.conf" do
        source "dnsmasq.conf.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :run, "bash[restart-quantum-head]", :delayed
    end
    template "/etc/quantum/l3_agent.ini" do
        source "l3_agent.ini.erb"
        owner "root"
        group "root"
        mode 00644
        notifies :run, "bash[restart-quantum-head]", :delayed
    end
end

# create signin dir if it does not exist
directory node['bcpc']['quantum']['signing_dir'] do
  owner "quantum"
  group "quantum"
  mode 0700
  action :create
end

# create database
ruby_block "quantum-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['quantum_dbname']}\"'|grep \"#{node['bcpc']['quantum_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['quantum_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['quantum_dbname']}.* TO '#{get_config('mysql-quantum-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-quantum-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['quantum_dbname']}.* TO '#{get_config('mysql-quantum-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-quantum-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
        end
    end
end

bash "restart-quantum-head" do
    action :nothing
    notifies :restart, "service[quantum-server]", :immediately
    notifies :restart, "service[quantum-metadata-agent]", :immediately
    case node['bcpc']['quantum']['plugin']
    when "linuxbridge"
        notifies :restart, "service[quantum-dhcp-agent]", :immediately
        notifies :restart, "service[quantum-l3-agent]", :immediately
        notifies :restart, "service[quantum-plugin-linuxbridge-agent]", :immediately
    end
end

# config default security group
bash "quantum-default-secgroup" do
    user "root"
    code <<-EOH
        . /root/adminrc
	quantum security-group-rule-create --protocol tcp --port_range_min 22 --port_range_max 22 --remote_ip_prefix 0.0.0.0/0 default
	quantum security-group-rule-create --protocol icmp --remote_ip_prefix 0.0.0.0/0 default
    EOH
    not_if ". /root/adminrc; quantum security-group-show default | grep icmp"
end

# create external networki, depends on plugin
bash "quantum-create-external-network" do
    case node['bcpc']['quantum']['core_plugin']
    when "quantum.plugins.linuxbridge.lb_quantum_plugin.LinuxBridgePluginV2"
        user "root"
        code <<-EOH
            . /root/adminrc
	    quantum net-create external --provider:network_type flat --provider:physical_network #{node['bcpc']['lb']['physical']} --router:external=True
	    quantum subnet-create external --allocation-pool start=#{node['bcpc']['floating']['pool_start']},end=#{node['bcpc']['floating']['pool_end']} --gateway=#{node['bcpc']['floating']['gateway']} #{node['bcpc']['floating']['cidr']} -- --enable_dhcp=False
        EOH
        not_if ". /root/adminrc; quantum net-list | grep external"
    end
end

