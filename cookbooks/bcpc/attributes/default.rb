###########################################
#
#  General configuration for this cluster
#
###########################################
default['bcpc']['country'] = "US"
default['bcpc']['state'] = "NY"
default['bcpc']['location'] = "New York"
default['bcpc']['organization'] = "Bloomberg"
default['bcpc']['openstack_release'] = "mitaka"
default['bcpc']['openstack_branch'] = "updates"
# Should be kvm (or qemu if testing in VMs that don't support VT-x)
default['bcpc']['virt_type'] = "kvm"
# Define the kernel to be installed. By default, track latest LTS kernel
default['bcpc']['preseed']['kernel'] = "linux-image-generic-lts-trusty"
# Define a specific kernel version to have GRUB default to (if non-nil)
# - specify kernel like pattern "3.13.0-61-generic"
# - a wrong pattern here will result in Chef convergence failure
default['bcpc']['kernel_version'] = nil
# ulimits for libvirt-bin
default['bcpc']['libvirt-bin']['ulimit']['nofile'] = 4096
# Region name for this cluster
default['bcpc']['region_name'] = node.chef_environment
# Domain name for this cluster (used in many configs)
default['bcpc']['cluster_domain'] = "bcpc.example.com"
# Hypervisor domain (domain used by actual machines)
default['bcpc']['hypervisor_domain'] = "hypervisor-bcpc.example.com"
# custom SSL certificate (specify filename).
# certificate files should be stored under 'files/default' directory
default['bcpc']['ssl_certificate'] = nil
default['bcpc']['ssl_private_key'] = nil
default['bcpc']['ssl_intermediate_certificate'] = nil

###########################################
#
#  Maintenance attribute for nodes
#
###########################################
# Use this attribute to mark a node as in maintenance
# (don't set it in the environment!)
default['bcpc']['in_maintenance'] = false

###########################################
#
#  Flags to enable/disable BCPC cluster features
#
###########################################
# This will enable elasticsearch & kibana on monitoring nodes and fluentd on
# all nodes
default['bcpc']['enabled']['logging'] = true
# This will enable graphite web and carbon on monitoring nodes and diamond on
# all nodes
default['bcpc']['enabled']['metrics'] = true
# This will enable zabbix server on monitoring nodes and zabbix agent on all
# nodes
default['bcpc']['enabled']['monitoring'] = true
# This will enable powerdns on head nodes
default['bcpc']['enabled']['dns'] = true
# This will enable iptables firewall on all nodes
default['bcpc']['enabled']['host_firewall'] = true
# This will enable of encryption of the chef data bag
default['bcpc']['enabled']['encrypt_data_bag'] = false
# These will enable automatic dist-upgrade/upgrade at the start of a Chef run
# (not recommended for stability)
default['bcpc']['enabled']['apt_dist_upgrade'] = false
default['bcpc']['enabled']['apt_upgrade'] = false
# This will enable running apt-get update at the start of every Chef run
default['bcpc']['enabled']['always_update_package_lists'] = true
# This will enable the extra healthchecks for keepalived (VIP management)
default['bcpc']['enabled']['keepalived_checks'] = true
# This will enable the networking test scripts
default['bcpc']['enabled']['network_tests'] = true
# This will enable TPM features
default['bcpc']['enabled']['tpm'] = false
# This will enable using a hardware RNG
default['bcpc']['enabled']['hwrng'] = false
# This will block VMs from talking to the management network
default['bcpc']['enabled']['secure_fixed_networks'] = true
# Toggle to enable/disable swap memory
default['bcpc']['enabled']['swap'] = true
# Toggle to enable apport for debugging process crashes
default['bcpc']['enabled']['apport'] = true
# Toggle to enable/disable Heat (OpenStack Cloud Formation)
default['bcpc']['enabled']['heat'] = false
# Toggle to switch between Neutron+Calico and nova-network
# SET BEFORE BUILDING, CHANGING ON EXISTING CLUSTER WILL CAUSE DEVASTATION
default['bcpc']['enabled']['neutron'] = false

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
# RabbitMQ settings
#
###########################################
# if changing this setting, you will need to reset Mnesia
# on all RabbitMQ nodes in the cluster
default['bcpc']['rabbitmq']['durable_queues'] = true
# ulimits for RabbitMQ server
default['bcpc']['rabbitmq']['ulimit']['nofile'] = 4096
# Heartbeat timeout to detect dead RabbitMQ brokers
default['bcpc']['rabbitmq']['heartbeat'] = 60

###########################################
#
#  Network settings for the cluster
#
###########################################
default['bcpc']['management']['vip'] = "10.17.1.15"
default['bcpc']['management']['netmask'] = "255.255.255.0"
default['bcpc']['management']['cidr'] = "10.17.1.0/24"
default['bcpc']['management']['gateway'] = "10.17.1.1"
default['bcpc']['management']['interface'] = nil
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['management']['interface-parent'] = nil
# list of extra TCP ports that should be open on the management interface
# (generally stuff served via HAProxy)
# some ports are hardcoded - see bcpc-firewall.erb template
default['bcpc']['management']['firewall_tcp_ports'] = [
  8088,7480,35357,8004,8000
]

default['bcpc']['metadata']['ip'] = "169.254.169.254"

default['bcpc']['storage']['netmask'] = "255.255.255.0"
default['bcpc']['storage']['cidr'] = "10.17.2.0/24"
default['bcpc']['storage']['gateway'] = "10.17.2.1"
default['bcpc']['storage']['interface'] = nil
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['storage']['interface-parent'] = nil

default['bcpc']['floating']['netmask'] = "255.255.255.0"
default['bcpc']['floating']['cidr'] = "192.168.43.0/24"
default['bcpc']['floating']['gateway'] = "192.168.43.2"
default['bcpc']['floating']['available_subnet'] = "192.168.43.128/25"
default['bcpc']['floating']['interface'] = nil
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['floating']['interface-parent'] = nil

default['bcpc']['fixed']['cidr'] = "10.17.16.0/20"
default['bcpc']['fixed']['vlan_start'] = "1000"
default['bcpc']['fixed']['num_networks'] = "16"
default['bcpc']['fixed']['network_size'] = "256"
default['bcpc']['fixed']['dhcp_lease_time'] = "120"

default['bcpc']['ntp_servers'] = ["pool.ntp.org"]
default['bcpc']['dns_servers'] = ["8.8.8.8", "8.8.4.4"]

# Proxy server URL for recipes to use
# Example: http://proxy-hostname:port
default['bcpc']['proxy_server_url'] = nil

###########################################
#
#  Repos for things we rely on
#
###########################################
default['bcpc']['repos']['rabbitmq'] = "http://www.rabbitmq.com/debian"
default['bcpc']['repos']['mysql'] = "http://repo.percona.com/apt"
default['bcpc']['repos']['haproxy'] = "http://ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu"
default['bcpc']['repos']['openstack'] = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/2/ubuntu/#{node['lsb']['codename']}"
default['bcpc']['repos']['elasticsearch'] = "http://packages.elasticsearch.org/elasticsearch/1.5/debian"
default['bcpc']['repos']['kibana'] = "http://packages.elasticsearch.org/kibana/4.1/debian"
default['bcpc']['repos']['erlang'] = "http://packages.erlang-solutions.com/ubuntu"
default['bcpc']['repos']['ceph'] = "http://download.ceph.com/debian-hammer"
default['bcpc']['repos']['zabbix'] = "http://repo.zabbix.com/zabbix/2.4/ubuntu"
default['bcpc']['repos']['mitaka-staging'] = "http://ppa.launchpad.net/ubuntu-cloud-archive/mitaka-staging/ubuntu"
default['bcpc']['repos']['calico'] = "http://ppa.launchpad.net/project-calico/calico-2.6/ubuntu"
default['bcpc']['repos']['bird'] = "http://ppa.launchpad.net/cz.nic-labs/bird/ubuntu"

###########################################
#
#  Default names for db's, pools, and users
#
###########################################
default['bcpc']['dbname']['nova'] = "nova"
default['bcpc']['dbname']['nova_api'] = "nova_api"
default['bcpc']['dbname']['cinder'] = "cinder"
default['bcpc']['dbname']['glance'] = "glance"
default['bcpc']['dbname']['horizon'] = "horizon"
default['bcpc']['dbname']['keystone'] = "keystone"
default['bcpc']['dbname']['neutron'] = "neutron"
default['bcpc']['dbname']['heat'] = "heat"
default['bcpc']['dbname']['graphite'] = "graphite"
default['bcpc']['dbname']['pdns'] = "pdns"
default['bcpc']['dbname']['zabbix'] = "zabbix"

default['bcpc']['zabbix']['user'] = "zabbix"
default['bcpc']['zabbix']['group'] = "adm"

# Can be set to 'http' or 'https'
default['bcpc']['protocol']['keystone'] = "https"
default['bcpc']['protocol']['glance'] = "https"
default['bcpc']['protocol']['nova'] = "https"
default['bcpc']['protocol']['cinder'] = "https"
default['bcpc']['protocol']['neutron'] = "https"
default['bcpc']['protocol']['heat'] = "https"

###########################################
#
#  Memcached Settings
#
###########################################
#
# Enable memcached double verbose logging.
default['bcpc']['memcached']['debug'] = false
# Set number of memcached connections.
default['bcpc']['memcached']['connections'] = 10240

###########################################
#
#  Horizon Settings
#
###########################################
#
# List panels to remove from the Horizon interface here
# (if the last panel in a group is removed, the group will also be removed)
default['bcpc']['horizon']['disable_panels'] = ['containers']


###########################################
#
#  Metadata Settings
#
###########################################

# load a custom vendor driver,
# e.g. "nova.api.metadata.bcpc_metadata.BcpcMetadata",
# comment out to use default
#default['bcpc']['vendordata_driver'] = "nova.api.metadata.bcpc_metadata.BcpcMetadata"

###########################################
#
# Routemon settings
#
###########################################
#

# numfixes is how many times to try and fix default routes in the mgmt
# and storage networks when they disappear. If numfixes starts off at
# 0, or after 'numfixes' attempts have been made, then routemon
# subsequently only monitors and reports
#
default['bcpc']['routemon']['numfixes'] = 0

###########################################
#
# MySQL settings
#
###########################################
#
# If set to 0, max_connections for MySQL on heads will default to an
# auto-calculated value.
default['bcpc']['mysql-head']['max_connections'] = 0
# for pools larger than 1GB, it is recommended to divide it into multiple
# pools of at least 1GB in size each
default['bcpc']['mysql-head']['innodb_buffer_pool_instances'] = 1
default['bcpc']['mysql-head']['innodb_buffer_pool_size'] = '128M'
default['bcpc']['mysql-head']['thread_cache_size'] = nil
default['bcpc']['mysql-head']['innodb_io_capacity'] = 200
default['bcpc']['mysql-head']['innodb_log_buffer_size'] = '8M'
default['bcpc']['mysql-head']['innodb_flush_method'] = 'O_DIRECT'
default['bcpc']['mysql-head']['wsrep_slave_threads'] = 4
default['bcpc']['mysql-head']['max_heap_table_size'] = '16M'
default['bcpc']['mysql-head']['join_buffer_size'] = '256K'
default['bcpc']['mysql-head']['sort_buffer_size'] = '256K'
default['bcpc']['mysql-head']['tmp_table_size'] = '16M'
# slow query log settings
default['bcpc']['mysql-head']['slow_query_log'] = true
default['bcpc']['mysql-head']['slow_query_log_file'] = '/var/log/mysql/slow.log'
default['bcpc']['mysql-head']['long_query_time'] = 10
default['bcpc']['mysql-head']['log_queries_not_using_indexes'] = false

###########################################
#
# BCPC system (sysctl) settings
#
###########################################
#
# Use this to *add* more reserved ports; i.e. modify value of
# net.ipv4.ip_local_reserved_ports
default['bcpc']['system']['additional_reserved_ports'] = []
# Any other sysctl parameters (register under parameters)
default['bcpc']['system']['parameters']['kernel.pid_max'] = 4194303
# Connection tracking table max size
default['bcpc']['system']['parameters']['net.nf_conntrack_max'] = 262144
# readhead value for all disks in the system, in kb
default['bcpc']['system']['readahead_kb'] = 512
# set to HWRNG source or leave as nil for rng-tools autodetect
default['bcpc']['system']['hwrng_source'] = nil

###########################################
#
# BCPC system hardware settings
#
###########################################
#
# Select desired I/O scheduler to be applied at startup (deadline, noop, cfq)
default['bcpc']['hardware']['io_scheduler'] = 'deadline'
# Enable power-saving CPU scaling governor (ondemand <3.19, powersave >=3.19)
default['bcpc']['hardware']['powersave'] = false

###########################################
#
# defaults for the bcpc.bootstrap settings
#
###########################################
#
# A value of nil means to let the Ubuntu installer work it out - it
# will try to find the nearest one. However the selected mirror is
# often slow.
default['bcpc']['bootstrap']['mirror'] = nil
#
# if you do specify a mirror, you can adjust the file path that comes
# after the hostname in the URL here
default['bcpc']['bootstrap']['mirror_path'] = "/ubuntu"
#
# worked example for the columbia mirror mentioned above which has a
# non-standard path
#default['bcpc']['bootstrap']['mirror']      = "mirror.cc.columbia.edu"
#default['bcpc']['bootstrap']['mirror_path'] = "/pub/linux/ubuntu/archive"

###########################################
#
# Openstack Flavors
#
###########################################

default['bcpc']['flavors'] = {
  "generic1.tiny" => {
    "vcpus" => 1,
    "memory_mb" => 512,
    "disk_gb" => 1,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic1.small" => {
    "vcpus" => 1,
    "memory_mb" => 2048,
    "disk_gb" => 20,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic1.medium" => {
    "vcpus" => 2,
    "memory_mb" => 4096,
    "disk_gb" => 40,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic1.large" => {
    "vcpus" => 4,
    "memory_mb" => 8192,
    "disk_gb" => 40,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic1.xlarge" => {
    "vcpus" => 8,
    "memory_mb" => 16384,
    "disk_gb" => 40,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic1.2xlarge" => {
    "vcpus" => 16,
    "memory_mb" => 32768,
    "disk_gb" => 40,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic2.small" => {
    "vcpus" => 1,
    "memory_mb" => 6144,
    "disk_gb" => 50,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic2.medium" => {
    "vcpus" => 2,
    "memory_mb" => 12288,
    "disk_gb" => 100,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic2.large" => {
    "vcpus" => 4,
    "memory_mb" => 24576,
    "disk_gb" => 100,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic2.xlarge" => {
    "vcpus" => 8,
    "memory_mb" => 49152,
    "disk_gb" => 100,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  },
  "generic2.2xlarge" => {
    "vcpus" => 16,
    "memory_mb" => 98304,
    "disk_gb" => 100,
    "extra_specs" => {
      "aggregate_instance_extra_specs:general_compute" => "yes",
    }
  }
}
default['bcpc']['flavor_access'] = { }

###########################################
#
# Openstack Host Aggregates
#
###########################################

default['bcpc']['host_aggregates'] = {
  "general_compute" => {
    "general_compute" => "yes",
    "maintenance" => "no"
  },
  "maintenance" => {
    "general_compute" => "no",
    "maintenance" => "yes"
  }
}

default['bcpc']['aggregate_membership'] = []

###########################################
#
# Openstack Project Quotas
#
###########################################
default['bcpc']['quota'] = {
    'nova' => {
        'admin' => {
           'cores'        => -1,
           'ram'          => -1,
           'floating_ips' => -1
        }
    }
}

###########################################
#
#  Getty settings
#
###########################################
default['bcpc']['getty']['ttys'] = %w( ttyS0 ttyS1 )

###########################################
#
#  VNC settings
#
###########################################
#
# VNC uses cluster domain name by default
# for proxy base url. Set to 'true' to use vip
default['bcpc']['vnc']['proxy_use_vip'] = false

###########################################
#
#  Bootstrap tftpd settings
#
###########################################
#
# Address and port to listen
default['bcpc']['tftpd']['address'] = ':69'
