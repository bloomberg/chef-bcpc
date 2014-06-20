#
# Cookbook Name:: kafka-bcpc 
# Recipe: Zookeeper

include_recipe "kafka::_setup"

file "#{node[:zookeeper][:data_dir]}/myid" do
  content "#{IPAddr.new(node[:ipaddress]).mask("0.0.0.255").to_i}\n"
  owner node[:kafka][:user]
  group node[:kafka][:group]
  action :create_if_missing
end
