###########################################
#
#  General configuration for this cluster
#
###########################################

default['bcpc']['management']['interface'] = 'eth0'
default['bcpc']['management']['vip'] = '10.17.1.15'
default['bcpc']['management']['netmask'] = '255.255.255.0'
default['bcpc']['management']['cidr'] = '10.17.1.0/24'
default['bcpc']['management']['gateway'] = '10.17.1.1'

default['bcpc']['storage']['interface'] = 'eth1'
default['bcpc']['storage']['vlan_interface'] = 'eth1.10'
default['bcpc']['storage']['netmask'] = '255.255.255.0'
default['bcpc']['storage']['cidr'] = '100.100.0.0/24'
default['bcpc']['storage']['gateway'] = '100.100.0.1'

default['bcpc']['floating']['interface'] = 'eth2'
default['bcpc']['floating']['vlan_interface'] = 'eth2.127'
default['bcpc']['floating']['netmask'] = '255.255.255.0'
default['bcpc']['floating']['cidr'] = '192.168.43.0/24'
default['bcpc']['floating']['gateway'] = '192.168.43.2'

default['bcpc']['hdfs_disks'] = [ 'sdb', 'sdc', 'sdd', 'sde' ]
