###########################################
#
# Rally settings
#
###########################################
if node.chef_environment == "Test-Laptop-Vagrant"
   default['bcpc']['rally']['user'] = 'vagrant'
else
   default['bcpc']['rally']['user'] = 'operations'
end
default['bcpc']['rally']['version'] = '0.9.1'
