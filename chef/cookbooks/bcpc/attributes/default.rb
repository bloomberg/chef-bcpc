###############################################################################
# cloud
###############################################################################

default['bcpc']['cloud']['region'] = node.chef_environment

###############################################################################
# file server
###############################################################################

default['bcpc']['file_server']['url'] = 'http://bootstrap:8080'

###############################################################################
# ubuntu
###############################################################################

default['bcpc']['ubuntu']['archive_url'] = 'http://archive.ubuntu.com/ubuntu'
default['bcpc']['ubuntu']['security_url'] = 'http://security.ubuntu.com/ubuntu'
default['bcpc']['ubuntu']['codename'] = node['lsb']['codename']
default['bcpc']['ubuntu']['components'] = %w(main restricted universe multiverse)

###############################################################################
# grub
###############################################################################

default['bcpc']['grub']['cmdline_linux'] = []

###############################################################################
# local_proxy
###############################################################################

default['bcpc']['local_proxy']['enabled'] = false
default['bcpc']['local_proxy']['config']['listen'] = '127.0.0.1'
default['bcpc']['local_proxy']['config']['port'] = '8888'

###############################################################################
# rabbitmq
###############################################################################

default['bcpc']['rabbitmq']['repo']['enabled'] = false
default['bcpc']['rabbitmq']['repo']['url'] = 'http://dl.bintray.com/rabbitmq/debian'

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
default['bcpc']['mysql']['max_connections'] = 8192

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
default['bcpc']['mysql']['max_heap_table_size'] = '16M'
default['bcpc']['mysql']['tmp_table_size'] = '16M'
default['bcpc']['mysql']['join_buffer_size'] = '256K'
default['bcpc']['mysql']['sort_buffer_size'] = '256K'

# slow query log settings
default['bcpc']['mysql']['slow_query_log'] = true
default['bcpc']['mysql']['slow_query_log_file'] = '/var/log/mysql/slow.log'
default['bcpc']['mysql']['long_query_time'] = 10
default['bcpc']['mysql']['log_queries_not_using_indexes'] = false
default['bcpc']['mysql']['service_hostname'] = 'primary.mysql.service.consul'

###############################################################################
# haproxy
###############################################################################

default['bcpc']['haproxy']['apt']['enabled'] = false
default['bcpc']['haproxy']['apt']['url'] = 'http://ppa.launchpad.net/vbernat/haproxy-1.8/ubuntu'

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
# memcached
###############################################################################

# Enable memcached double verbose logging.
default['bcpc']['memcached']['debug'] = false
# Set number of memcached connections.
default['bcpc']['memcached']['connections'] = 10240

###############################################################################
# virtualbox
###############################################################################

default['bcpc']['virtualbox']['nat_ip'] = '10.0.2.15'
