###########################################
#
# Rally settings
#
###########################################
if node.chef_environment == "Test-Laptop-Vagrant"
   default['bcpc-extra']['rally']['user'] = 'vagrant'
else
   default['bcpc-extra']['rally']['user'] = 'operations'
end
default['bcpc-extra']['rally']['version'] = '0.9.2'
