#
# Cookbook Name:: kafka-bcpc 
# Recipe: Zookeeper

file "#{node[:zookeeper][:data_dir]}/myid" do
  content "#{IPAddr.new(node[:ipaddress]).mask("0.0.0.255").to_i}\n"
  action :create_if_missing
end
