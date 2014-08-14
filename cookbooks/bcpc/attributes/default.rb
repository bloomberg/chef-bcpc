###########################################
#
#  General configuration for this cluster
#
###########################################
default['bcpc']['country'] = "US"
default['bcpc']['state'] = "NY"
default['bcpc']['location'] = "New York"
default['bcpc']['organization'] = "Bloomberg"
default['bcpc']['openstack_release'] = "icehouse"
# Can be "updates" or "proposed"
default['bcpc']['openstack_branch'] = "proposed"
# Should be kvm (or qemu if testing in VMs that don't support VT-x)
default['bcpc']['virt_type'] = "kvm"
# Region name for this cluster
default['bcpc']['region_name'] = node.chef_environment
# Domain name for this cluster (used in many configs)
default['bcpc']['domain_name'] = "bcpc.example.com"
# Key if Cobalt+VMS is to be used
default['bcpc']['vms_key'] = nil

###########################################
#
#  Flags to enable/disable BCPC cluster features
#
###########################################
# This will enable elasticsearch & kibana on head nodes and fluentd on all nodes
default['bcpc']['enabled']['logging'] = true
# This will enable graphite web and carbon on head nodes and diamond on all nodes
default['bcpc']['enabled']['metrics'] = true
# This will enable zabbix server on head nodes and zabbix agent on all nodes
default['bcpc']['enabled']['monitoring'] = true
# This will enable powerdns on head nodes
default['bcpc']['enabled']['dns'] = true
# This will enable iptables firewall on all nodes
default['bcpc']['enabled']['host_firewall'] = true
# This will enable of encryption of the chef data bag
default['bcpc']['enabled']['encrypt_data_bag'] = false
# This will enable auto-upgrades on all nodes (not recommended for stability)
default['bcpc']['enabled']['apt_upgrade'] = false
# This will enable the extra healthchecks for keepalived (VIP management)
default['bcpc']['enabled']['keepalived_checks'] = true
# This will enable the networking test scripts
default['bcpc']['enabled']['network_tests'] = true

# This can be either 'sql' or 'ldap' to either store identities
# in the mysql DB or the LDAP server
default['bcpc']['keystone']['backend'] = 'ldap'

###########################################
#
#  Host-specific defaults for the cluster
#
###########################################
default['bcpc']['ceph']['hdd_disks'] = ["sdb", "sdc"]
default['bcpc']['ceph']['ssd_disks'] = ["sdd", "sde"]
default['bcpc']['ceph']['enabled_pools'] = ["ssd", "hdd"]
default['bcpc']['management']['interface'] = "eth0"
default['bcpc']['storage']['interface'] = "eth1"
default['bcpc']['floating']['interface'] = "eth2"
default['bcpc']['fixed']['vlan_interface'] = node['bcpc']['floating']['interface']

###########################################
#
#  Ceph settings for the cluster
#
###########################################
default['bcpc']['ceph']['chooseleaf'] = "rack"
default['bcpc']['ceph']['pgp_auto_adjust'] = false
default['bcpc']['ceph']['pgs_per_node'] = 1024
# The 'portion' parameters should add up to ~100 across all pools
default['bcpc']['ceph']['default']['replicas'] = 2
default['bcpc']['ceph']['default']['type'] = 'hdd'
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
default['bcpc']['ceph']['ssd']['ruleset'] = 1
default['bcpc']['ceph']['hdd']['ruleset'] = 2

###########################################
#
#  Network settings for the cluster
#
###########################################
default['bcpc']['management']['vip'] = "10.17.1.15"
default['bcpc']['management']['netmask'] = "255.255.255.0"
default['bcpc']['management']['cidr'] = "10.17.1.0/24"
default['bcpc']['management']['gateway'] = "10.17.1.1"
default['bcpc']['metadata']['ip'] = "169.254.169.254"

default['bcpc']['storage']['netmask'] = "255.255.255.0"
default['bcpc']['storage']['cidr'] = "100.100.0.0/24"
default['bcpc']['storage']['gateway'] = "100.100.0.1"

default['bcpc']['floating']['vip'] = "192.168.43.15"
default['bcpc']['floating']['netmask'] = "255.255.255.0"
default['bcpc']['floating']['cidr'] = "192.168.43.0/24"
default['bcpc']['floating']['gateway'] = "192.168.43.2"
default['bcpc']['floating']['available_subnet'] = "192.168.43.128/25"

default['bcpc']['fixed']['cidr'] = "1.127.0.0/16"
default['bcpc']['fixed']['vlan_start'] = "1000"
default['bcpc']['fixed']['num_networks'] = "100"
default['bcpc']['fixed']['network_size'] = "256"
default['bcpc']['fixed']['dhcp_lease_time'] = 3600

default['bcpc']['ntp_servers'] = ["pool.ntp.org"]
default['bcpc']['dns_servers'] = ["8.8.8.8", "8.8.4.4"]

###########################################
#
#  Repos for things we rely on
#
###########################################
default['bcpc']['repos']['ceph'] = "http://www.ceph.com/debian-firefly"
default['bcpc']['repos']['ceph-extras'] = "http://www.ceph.com/packages/ceph-extras/debian"
default['bcpc']['repos']['ceph-el6-x86_64'] = "http://ceph.com/rpm-dumpling/el6/x86_64"
default['bcpc']['repos']['ceph-el6-noarch'] = "http://ceph.com/rpm-dumpling/el6/noarch"
default['bcpc']['repos']['rabbitmq'] = "http://www.rabbitmq.com/debian"
default['bcpc']['repos']['mysql'] = "http://repo.percona.com/apt"
default['bcpc']['repos']['haproxy'] = "http://ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu"
default['bcpc']['repos']['openstack'] = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
default['bcpc']['repos']['hwraid'] = "http://hwraid.le-vert.net/ubuntu"
default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/precise"
default['bcpc']['repos']['ceph-apache'] = "http://gitbuilder.ceph.com/apache2-deb-precise-x86_64-basic/ref/master"
default['bcpc']['repos']['ceph-fcgi'] = "http://gitbuilder.ceph.com/libapache-mod-fastcgi-deb-precise-x86_64-basic/ref/master"
default['bcpc']['repos']['gridcentric'] = "http://downloads.gridcentric.com/packages/%s/%s/ubuntu"

###########################################
#
# [Optional] If using apt-mirror to pull down repos, we use these settings.
#
###########################################
# Note - us.archive.ubuntu.com tends to rate-limit pretty hard.
# If you are on East Coast US, we recommend Columbia University in env file:
# "mirror" : {
#  "ubuntu": "mirror.cc.columbia.edu/pub/linux/ubuntu/archive"
# }
# For a complete list of Ubuntu mirrors, please see:
# https://launchpad.net/ubuntu/+archivemirrors
default['bcpc']['mirror']['ubuntu'] = "us.archive.ubuntu.com/ubuntu"
default['bcpc']['mirror']['ubuntu-dist'] = ['precise']
default['bcpc']['mirror']['ceph-dist'] = ['firefly']
default['bcpc']['mirror']['os-dist'] = ['icehouse']

###########################################
#
#  Default names for db's, pools, and users
#
###########################################
default['bcpc']['dbname']['nova'] = "nova"
default['bcpc']['dbname']['cinder'] = "cinder"
default['bcpc']['dbname']['glance'] = "glance"
default['bcpc']['dbname']['horizon'] = "horizon"
default['bcpc']['dbname']['keystone'] = "keystone"
default['bcpc']['dbname']['heat'] = "heat"
default['bcpc']['dbname']['ceilometer'] = "ceilometer"
default['bcpc']['dbname']['graphite'] = "graphite"
default['bcpc']['dbname']['pdns'] = "pdns"
default['bcpc']['dbname']['zabbix'] = "zabbix"
default['bcpc']['dbname']['sahara'] = "sahara"

default['bcpc']['admin_tenant'] = "AdminTenant"
default['bcpc']['admin_role'] = "Admin"
default['bcpc']['member_role'] = "Member"
default['bcpc']['admin_email'] = "admin@localhost.com"

default['bcpc']['zabbix']['user'] = "zabbix"
default['bcpc']['zabbix']['group'] = "adm"

default['bcpc']['ports']['apache']['radosgw'] = 80
default['bcpc']['ports']['apache']['radosgw_https'] = 443
default['bcpc']['ports']['haproxy']['radosgw'] = 80
default['bcpc']['ports']['haproxy']['radosgw_https'] = 443

# Can be set to 'http' or 'https'
default['bcpc']['protocol']['keystone'] = "https"
default['bcpc']['protocol']['glance'] = "https"
default['bcpc']['protocol']['nova'] = "https"
default['bcpc']['protocol']['cinder'] = "https"
default['bcpc']['protocol']['heat'] = "https"
default['bcpc']['protocol']['sahara'] = "http"

# Location for sahara vanilla ubuntu image
default['bcpc']['sahara']['vanilla_img_location'] = "http://sahara-files.mirantis.com/sahara-icehouse-vanilla-1.2.1-ubuntu-13.10.qcow2"
default['bcpc']['sahara']['vanilla_hadoop_version'] = "1.2.1"

