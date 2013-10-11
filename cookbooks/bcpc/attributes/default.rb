###########################################
#
#  General configuration for this cluster
#
###########################################
default['bcpc']['country'] = "US"
default['bcpc']['state'] = "NY"
default['bcpc']['location'] = "New York"
default['bcpc']['organization'] = "Bloomberg"
# Can be "folsom" or "grizzly"
default['bcpc']['openstack_release'] = "grizzly"
# Can be "updates" or "proposed"
default['bcpc']['openstack_branch'] = "proposed"
# Should be kvm (or qemu if testing in VMs)
default['bcpc']['virt_type'] = "kvm"
# Region name for this cluster
default['bcpc']['region_name'] = node.chef_environment
# Domain name that will be used for DNS
default['bcpc']['domain_name'] = "bcpc.example.com"
# Key if Cobalt+VMS is to be used
default['bcpc']['vms_key'] = nil

###########################################
#
#  Host-specific defaults for the cluster
#
###########################################
default['bcpc']['ceph_disks'] = [ "sdb", "sdc", "sdd", "sde" ]
default['bcpc']['management']['interface'] = "eth0"
default['bcpc']['storage']['interface'] = "eth1"
default['bcpc']['floating']['interface'] = "eth2"
default['bcpc']['fixed']['vlan_interface'] = node[:bcpc][:floating][:interface]

###########################################
#
#  Network settings for the cluster
#
###########################################
default['bcpc']['management']['vip'] = "10.17.1.15"
default['bcpc']['management']['netmask'] = "255.255.255.0"
default['bcpc']['management']['cidr'] = "10.17.1.0/24"
default['bcpc']['management']['gateway'] = "10.17.1.1"

default['bcpc']['storage']['netmask'] = "255.255.255.0"
default['bcpc']['storage']['cidr'] = "100.100.0.0/24"
default['bcpc']['storage']['gateway'] = "100.100.0.1"

default['bcpc']['floating']['netmask'] = "255.255.255.0"
default['bcpc']['floating']['cidr'] = "192.168.43.0/24"
default['bcpc']['floating']['gateway'] = "192.168.43.2"
default['bcpc']['floating']['available_subnet'] = "192.168.43.128/25"

default['bcpc']['fixed']['cidr'] = "1.127.0.0/16"
default['bcpc']['fixed']['vlan_start'] = "1000"
default['bcpc']['fixed']['num_networks'] = "100"
default['bcpc']['fixed']['network_size'] = "256"

default['bcpc']['ntp_servers'] = [ "pool.ntp.org" ]
default['bcpc']['dns_servers'] = [ "8.8.8.8", "8.8.4.4" ]

###########################################
#
#  Repos for things we rely on
#
###########################################
default['bcpc']['repos']['ceph'] = "http://www.ceph.com/debian-dumpling"
default['bcpc']['repos']['ceph-el6-x86_64'] = "http://ceph.com/rpm-dumpling/el6/x86_64"
default['bcpc']['repos']['ceph-el6-noarch'] = "http://ceph.com/rpm-dumpling/el6/noarch"
default['bcpc']['repos']['rabbitmq'] = "http://www.rabbitmq.com/debian"
default['bcpc']['repos']['mysql'] = "http://repo.percona.com/apt"
default['bcpc']['repos']['openstack'] = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
default['bcpc']['repos']['hwraid'] = "http://hwraid.le-vert.net/ubuntu"
default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/precise"
default['bcpc']['repos']['gridcentric'] = "http://downloads.gridcentric.com/packages/%s/%s/ubuntu"

###########################################
#
#  Default names for db's, pools, and users
#
###########################################
default['bcpc']['nova_dbname'] = "nova"
default['bcpc']['cinder_dbname'] = "cinder"
default['bcpc']['glance_dbname'] = "glance"
default['bcpc']['horizon_dbname'] = "horizon"
default['bcpc']['keystone_dbname'] = "keystone"
default['bcpc']['graphite_dbname'] = "graphite"
default['bcpc']['pdns_dbname'] = "pdns"
default['bcpc']['zabbix_dbname'] = "zabbix"

default['bcpc']['cinder_rbd_pool'] = "volumes"
default['bcpc']['glance_rbd_pool'] = "images"
default['bcpc']['vms_disk_pool'] = "vmsdisk"
default['bcpc']['vms_mem_pool'] = "vmsmem"

default['bcpc']['admin_tenant'] = "AdminTenant"
default['bcpc']['admin_role'] = "Admin"
default['bcpc']['member_role'] = "Member"
default['bcpc']['admin_email'] = "admin@localhost.com"

default['bcpc']['zabbix']['user'] = "zabbix"
default['bcpc']['zabbix']['group'] = "adm"

