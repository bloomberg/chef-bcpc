


include_recipe 'chef_handler'

cookbook_file "#{node['chef_handler']['handler_path']}/restart_handler.rb" do
  source 'restart_handler.rb'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

chef_handler 'RestartHandler' do
  source "#{node['chef_handler']['handler_path']}/restart_handler.rb"
  if node[:bcpc][:allow_restarts] == 0
    action :disable
  else
    action :enable
  end
end
