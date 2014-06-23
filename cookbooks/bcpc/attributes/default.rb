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

default['bcpc']['encrypt_data_bag'] = false

default['bcpc']['bootstrap']['preseed']['late_command'] = "true"

###########################################
#
#  Host-specific defaults for the cluster
#
###########################################
default['bcpc']['bootstrap']['interface'] = "eth0"
default['bcpc']['bootstrap']['pxe_interface'] = "eth1"
default['bcpc']['bootstrap']['server'] = "10.0.100.3"
default['bcpc']['bootstrap']['dhcp_range'] = "10.0.100.14 10.0.100.250"
default['bcpc']['bootstrap']['dhcp_subnet'] = "10.0.100.0"

###########################################
#
#  Ceph settings for the cluster
#
###########################################
default['bcpc']['ceph']['pgs_per_node'] = 1024
default['bcpc']['ceph']['hdd_disks'] = [ "sdb", "sdc" ]
default['bcpc']['ceph']['ssd_disks'] = [ "sdd", "sde" ]
default['bcpc']['ceph']['enabled_pools'] = [ "ssd", "hdd" ]
# The 'portion' parameters should add up to ~100 across all pools
default['bcpc']['ceph']['rgw']['replicas'] = 3
default['bcpc']['ceph']['rgw']['portion'] = 33
default['bcpc']['ceph']['rgw']['type'] = 'hdd'
default['bcpc']['ceph']['images']['replicas'] = 3
default['bcpc']['ceph']['images']['portion'] = 33
default['bcpc']['ceph']['images']['type'] = 'ssd'
default['bcpc']['ceph']['images']['name'] = "images"
default['bcpc']['ceph']['volumes']['replicas'] = 3
default['bcpc']['ceph']['volumes']['portion'] = 33
default['bcpc']['ceph']['volumes']['name'] = "volumes"
default['bcpc']['ceph']['vms_disk']['replicas'] = 3
default['bcpc']['ceph']['vms_disk']['portion'] = 10
default['bcpc']['ceph']['vms_disk']['type'] = 'ssd'
default['bcpc']['ceph']['vms_disk']['name'] = "vmsdisk"
default['bcpc']['ceph']['vms_mem']['replicas'] = 3
default['bcpc']['ceph']['vms_mem']['portion'] = 10
default['bcpc']['ceph']['vms_mem']['type'] = 'ssd'
default['bcpc']['ceph']['vms_mem']['name'] = "vmsmem"

###########################################
#
#  Network settings for the cluster
#
###########################################
default['bcpc']['management']['vip'] = "10.17.1.15"
default['bcpc']['management']['netmask'] = "255.255.255.0"
default['bcpc']['management']['cidr'] = "10.17.1.0/24"
default['bcpc']['management']['gateway'] = "10.17.1.1"
default['bcpc']['management']['interface'] = "eth0"

default['bcpc']['metadata']['ip'] = "169.254.169.254"

default['bcpc']['storage']['netmask'] = "255.255.255.0"
default['bcpc']['storage']['cidr'] = "100.100.0.0/24"
default['bcpc']['storage']['gateway'] = "100.100.0.1"
default['bcpc']['storage']['interface'] = "eth1"

default['bcpc']['floating']['vip'] = "192.168.43.15"
default['bcpc']['floating']['netmask'] = "255.255.255.0"
default['bcpc']['floating']['cidr'] = "192.168.43.0/24"
default['bcpc']['floating']['gateway'] = "192.168.43.2"
default['bcpc']['floating']['available_subnet'] = "192.168.43.128/25"
default['bcpc']['floating']['interface'] = "eth2"

default['bcpc']['fixed']['cidr'] = "1.127.0.0/16"
default['bcpc']['fixed']['vlan_start'] = "1000"
default['bcpc']['fixed']['num_networks'] = "100"
default['bcpc']['fixed']['network_size'] = "256"
default['bcpc']['fixed']['vlan_interface'] = node[:bcpc][:floating][:interface]

default['bcpc']['ntp_servers'] = [ "pool.ntp.org" ]
default['bcpc']['dns_servers'] = [ "8.8.8.8", "8.8.4.4" ]

###########################################
#
#  Repos for things we rely on
#
###########################################
default['bcpc']['repos']['ceph'] = "http://www.ceph.com/debian-dumpling"
default['bcpc']['repos']['ceph-extras'] = "http://www.ceph.com/packages/ceph-extras/debian"
default['bcpc']['repos']['ceph-el6-x86_64'] = "http://ceph.com/rpm-dumpling/el6/x86_64"
default['bcpc']['repos']['ceph-el6-noarch'] = "http://ceph.com/rpm-dumpling/el6/noarch"
default['bcpc']['repos']['rabbitmq'] = "http://www.rabbitmq.com/debian"
default['bcpc']['repos']['mysql'] = "http://repo.percona.com/apt"
default['bcpc']['repos']['openstack'] = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
default['bcpc']['repos']['hwraid'] = "http://hwraid.le-vert.net/ubuntu"
default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/precise"
default['bcpc']['repos']['ceph-apache'] = "http://gitbuilder.ceph.com/apache2-deb-precise-x86_64-basic/ref/master"
default['bcpc']['repos']['ceph-fcgi'] = "http://gitbuilder.ceph.com/libapache-mod-fastcgi-deb-precise-x86_64-basic/ref/master"
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

default['bcpc']['admin_tenant'] = "AdminTenant"
default['bcpc']['admin_role'] = "Admin"
default['bcpc']['member_role'] = "Member"
default['bcpc']['admin_email'] = "admin@localhost.com"

default['bcpc']['zabbix']['user'] = "zabbix"
default['bcpc']['zabbix']['group'] = "adm"

default['bcpc']['keepalived']['config_template'] = "keepalived.conf_openstack"
default['bcpc']['graphite']['relay-port'] = 2013

default[:bcpc][:ports][:apache][:radosgw] = 8080
default[:bcpc][:ports][:apache][:radosgw_https] = 8443
default[:bcpc][:ports][:haproxy][:radosgw] = 80
default[:bcpc][:ports][:haproxy][:radosgw_https] = 443
