###############################################################################
# cloud
###############################################################################

default['bcpc']['cloud']['domain'] = 'bcpc.example.com'
default['bcpc']['cloud']['fqdn'] = "openstack.#{node['bcpc']['cloud']['domain']}"
default['bcpc']['cloud']['region'] = node.chef_environment
default['bcpc']['cloud']['vip'] = '10.10.254.254'

# list of dns servers to use
default['bcpc']['dns_servers'] = %w(8.8.8.8 8.8.4.4)

# list of ntp servers to use
default['bcpc']['ntp']['servers'] = %w(time1.google.com time2.google.com)

default['bcpc']['file_server']['url'] = 'http://bootstrap:8080'

# Hypervisor domain (domain used by actual machines)
default['bcpc']['hypervisor_domain'] = 'hypervisor-bcpc.example.com'

###############################################################################
# ubuntu
###############################################################################

default['bcpc']['ubuntu']['archive_url'] = 'http://archive.ubuntu.com/ubuntu'
default['bcpc']['ubuntu']['security_url'] = 'http://security.ubuntu.com/ubuntu'
default['bcpc']['ubuntu']['codename'] = node['lsb']['codename']
default['bcpc']['ubuntu']['components'] = %w(main restricted universe multiverse)
default['bcpc']['ubuntu']['arch'] = 'amd64'

###############################################################################
# proxy
###############################################################################

default['bcpc']['proxy']['enabled'] = false
default['bcpc']['proxy']['proxies']['http'] = ''
default['bcpc']['proxy']['proxies']['https'] = ''

###############################################################################
# rabbitmq
###############################################################################

# if changing this setting, you will need to reset Mnesia
# on all RabbitMQ nodes in the cluster
default['bcpc']['rabbitmq']['durable_queues'] = true

# ulimits for RabbitMQ server
default['bcpc']['rabbitmq']['ulimit']['nofile'] = 4096

# Heartbeat timeout to detect dead RabbitMQ brokers
default['bcpc']['rabbitmq']['heartbeat'] = 60

###############################################################################
# libvirt
###############################################################################

# ulimits for libvirt-bin
default['bcpc']['libvirt-bin']['ulimit']['nofile'] = 4096

###############################################################################
# mysql
###############################################################################

default['bcpc']['mysql']['apt']['enabled'] = true
default['bcpc']['mysql']['apt']['url'] = 'http://repo.percona.com/apt'

# fqdn of mysql server
#
default['bcpc']['mysql']['host'] = 'primary.mysql.service.consul'

# if set to 0, max_connections for MySQL on heads will default to an
# auto-calculated value.
#
default['bcpc']['mysql']['max_connections'] = 1024

# for pools larger than 1GB, it is recommended to divide it into multiple
# pools of at least 1GB in size each
#
default['bcpc']['mysql']['innodb_buffer_pool_instances'] = 1
default['bcpc']['mysql']['innodb_buffer_pool_size'] = '128M'
default['bcpc']['mysql']['thread_cache_size'] = nil
default['bcpc']['mysql']['innodb_io_capacity'] = 200
default['bcpc']['mysql']['innodb_log_buffer_size'] = '8M'
default['bcpc']['mysql']['innodb_flush_method'] = 'O_DIRECT'
default['bcpc']['mysql']['wsrep_slave_threads'] = 4

# slow query log settings
default['bcpc']['mysql']['slow_query_log'] = true
default['bcpc']['mysql']['slow_query_log_file'] = '/var/log/mysql/slow.log'
default['bcpc']['mysql']['long_query_time'] = 10
default['bcpc']['mysql']['log_queries_not_using_indexes'] = false
default['bcpc']['mysql']['service_hostname'] = 'primary.mysql.service.consul'

###############################################################################
# misc settings
###############################################################################

# pin the system kernel to a fixed version
default['bcpc']['kernel']['pin_version'] = false
default['bcpc']['kernel']['version'] = ''

# debugging process crashes
default['bcpc']['apport']['enabled'] = true

# enable/disable trusted platform module
default['bcpc']['tpm']['enabled'] = true

# enable/disable feed random data from hardware to kernel
default['bcpc']['hwrng']['enabled'] = true
default['bcpc']['hwrng']['source'] = nil

# enable/disable local firewall on hypervisor
default['bcpc']['host_firewall']['enabled'] = true

# list of extra TCP ports that should be open on the management interface
# (generally stuff served via HAProxy)
# some ports are hardcoded - see bcpc-firewall.erb template
default['bcpc']['management']['firewall_tcp_ports'] = [
  8088, 7480, 35357, 8004, 8000
]

# use this to *add* more reserved ports; i.e. modify value of
# net.ipv4.ip_local_reserved_ports
default['bcpc']['system']['additional_reserved_ports'] = []

# any other sysctl parameters (register under parameters)
default['bcpc']['system']['parameters']['kernel.pid_max'] = 4194303

# connection tracking table max size
default['bcpc']['system']['parameters']['net.nf_conntrack_max'] = 262144

# readhead value for all disks in the system, in kb
default['bcpc']['system']['readahead_kb'] = 512

# used for SOL (serial over lan) communication
default['bcpc']['getty']['ttys'] = %w(ttyS0 ttyS1)

# select desired I/O scheduler to be applied at startup (deadline, noop, cfq)
default['bcpc']['hardware']['io_scheduler'] = 'deadline'

# enable power-saving CPU scaling governor
default['bcpc']['hardware']['powersave']['enabled'] = false

###############################################################################
# horizon
###############################################################################

default['bcpc']['horizon']['disable_panels'] = ['containers']

###############################################################################
# metadata settings
###############################################################################

default['bcpc']['metadata']['vendordata']['enabled'] = false
# default['bcpc']['metadata']['vendordata']['driver'] = "nova.api.metadata.bcpc_metadata.BcpcMetadata"

###############################################################################
# bird
###############################################################################

default['bcpc']['bird']['repo']['enabled'] = false
default['bcpc']['bird']['repo']['url'] = ''

###############################################################################
# memcached
###############################################################################

# Enable memcached double verbose logging.
default['bcpc']['memcached']['debug'] = false
# Set number of memcached connections.
default['bcpc']['memcached']['connections'] = 10240

###############################################################################
# etcd
###############################################################################

default['bcpc']['etcd']['remote']['file'] = 'etcd-v3.3.7-linux-amd64.tar.gz'
default['bcpc']['etcd']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/etcd-v3.3.7-linux-amd64.tar.gz"
default['bcpc']['etcd']['remote']['checksum'] = '251605c618e789fe58e3b0c792ebf9304148d20de7840d475e840d6578e9093c'

###############################################################################
# virtualbox
###############################################################################

default['bcpc']['virtualbox']['nat_ip'] = '10.0.2.15'
