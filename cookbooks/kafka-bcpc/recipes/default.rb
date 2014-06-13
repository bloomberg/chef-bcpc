# Cookbook Name:: kafka-bcpc 
# Recipe:: default
# set vm.swapiness to 0 (to lessen swapping)

sysctl_param 'vm.swappiness' do
  value 0
end
