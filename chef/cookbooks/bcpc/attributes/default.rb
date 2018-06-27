require 'ipaddress'

###############################################################################
# cloud
###############################################################################

default['bcpc']['cloud']['domain'] = 'bcpc.example.com'
default['bcpc']['cloud']['fqdn'] = "openstack.#{default['bcpc']['cloud']['domain']}"
default['bcpc']['cloud']['region'] = node.chef_environment
default['bcpc']['cloud']['vip'] = {'ip': '10.10.254.254/32'}

default['bcpc']['dns_servers'] = ["8.8.8.8", "8.8.4.4"]
default['bcpc']['file_server']['url'] = 'http://bootstrap:8080'

# Hypervisor domain (domain used by actual machines)
default['bcpc']['hypervisor_domain'] = "hypervisor-bcpc.example.com"

# convenience variable
#
vip = IPAddress(node['bcpc']['cloud']['vip']['ip']).address

###############################################################################
# proxy
###############################################################################

#default['bcpc']['proxy']['enabled'] = true
#default['bcpc']['proxy']['proxies']['http'] = ''
#default['bcpc']['proxy']['proxies']['https'] = ''


###############################################################################
# pdns
###############################################################################

default['bcpc']['pdns']['interface'] = {'ip': '10.10.254.253/30'}


###############################################################################
# unbound
###############################################################################

pdns = IPAddress(node['bcpc']['pdns']['interface']['ip']).address
domain = default['bcpc']['cloud']['domain']

default['bcpc']['unbound']['default']['root_trust_anchor_update'] = false
default['bcpc']['unbound']['server']['access-control'] = '0.0.0.0/0 allow'
default['bcpc']['unbound']['server']['chroot'] = '""'
default['bcpc']['unbound']['server']['directory'] = '/etc/unbound'
default['bcpc']['unbound']['server']['do-ip4'] = 'yes'
default['bcpc']['unbound']['server']['do-udp'] = 'yes'
default['bcpc']['unbound']['server']['do-tcp'] = 'yes'
default['bcpc']['unbound']['server']['domain-insecure'] = '*'
default['bcpc']['unbound']['server']['interface'] = vip
default['bcpc']['unbound']['server']['logfile'] = '""'
default['bcpc']['unbound']['server']['num-threads'] = 2
default['bcpc']['unbound']['server']['pidfile'] = '/var/run/unbound.pid'
default['bcpc']['unbound']['server']['port'] = 53
default['bcpc']['unbound']['server']['use-syslog'] = 'yes'
default['bcpc']['unbound']['server']['verbosity'] = 1

# TLD quieries to forward to other name servers
#
default['bcpc']['unbound']['forward-zone']['consul'] = [vip + '@8600']
default['bcpc']['unbound']['forward-zone'][domain] = [pdns + '@53']
default['bcpc']['unbound']['forward-zone']['.'] = node['bcpc']['dns_servers']


###############################################################################
# rabbitmq
###############################################################################

default['bcpc']['rabbitmq']['repo']['enabled'] = false
default['bcpc']['rabbitmq']['repo']['url'] = "http://www.rabbitmq.com/debian"

default['bcpc']['erlang']['repo']['enabled'] = false
default['bcpc']['erlang']['repo']['url'] = "http://packages.erlang-solutions.com/ubuntu"

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
default['bcpc']['mysql']['apt']['url'] = "http://repo.percona.com/apt"

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
# haproxy
###############################################################################

default['bcpc']['haproxy']['apt']['enabled'] = false
default['bcpc']['haproxy']['apt']['url'] = "http://ppa.launchpad.net/vbernat/haproxy-1.8/ubuntu"


###############################################################################
# powerdns
###############################################################################

default['bcpc']['powerdns']['repo']['enabled'] = true
default['bcpc']['powerdns']['repo']['url'] = "http://repo.powerdns.com/ubuntu"
default['bcpc']['powerdns']['repo']['distro'] = "bionic-auth-master"


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
# This will enable iptables firewall on all nodes
default['bcpc']['enabled']['host_firewall'] = true

# This will enable TPM features
default['bcpc']['enabled']['tpm'] = false
# This will enable using a hardware RNG
default['bcpc']['enabled']['hwrng'] = false
# Toggle to enable apport for debugging process crashes
default['bcpc']['enabled']['apport'] = true

# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['management']['interface-parent'] = nil
# list of extra TCP ports that should be open on the management interface
# (generally stuff served via HAProxy)
# some ports are hardcoded - see bcpc-firewall.erb template
default['bcpc']['management']['firewall_tcp_ports'] = [
  8088,7480,35357,8004,8000
]

# Proxy server URL for recipes to use
# Example: http://proxy-hostname:port
default['bcpc']['proxy_server_url'] = nil

###############################################################################
# horizon
###############################################################################

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
#  Getty settings
#
###########################################
default['bcpc']['getty']['ttys'] = %w( ttyS0 ttyS1 )


###############################################################################
# bird
###############################################################################

default['bcpc']['bird']['repo']['enabled'] = false
default['bcpc']['bird']['repo']['url'] = ""


###############################################################################
# calico/calicoctl
###############################################################################

default['bcpc']['calico']['repo']['enabled'] = true
default['bcpc']['calico']['repo']['url'] = "http://ppa.launchpad.net/project-calico/calico-3.1/ubuntu"

default['bcpc']['calico']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/calicoctl"
default['bcpc']['calico']['remote']['checksum'] = '62ae2334f62ca5e5501022845a885efdae8cd10cfbe40293a58e3d85d39bc120'


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
# consul
###############################################################################

default['bcpc']['consul']['remote_file'] = {
  'file' => 'consul_1.1.0_linux_amd64.zip',
  'checksum' => '09c40c8b5be868003810064916d8460bff334ccfb59a5046390224b27e052c45'
}

default['bcpc']['consul']['executable'] = '/usr/local/sbin/consul'
default['bcpc']['consul']['conf_dir'] = '/etc/consul/conf.d'
default['bcpc']['consul']['config']['datacenter'] = node.chef_environment
default['bcpc']['consul']['config']['client_addr'] = '127.0.0.1'
default['bcpc']['consul']['config']['advertise_addr'] = node['ipaddress']
default['bcpc']['consul']['config']['data_dir'] = '/var/lib/consul'
default['bcpc']['consul']['config']['disable_update_check'] = true
default['bcpc']['consul']['config']['enable_script_checks'] = true
default['bcpc']['consul']['config']['server'] = true
default['bcpc']['consul']['config']['log_level'] = 'INFO'
default['bcpc']['consul']['config']['node_name'] = node['hostname']
default['bcpc']['consul']['config']['addresses']['dns'] = "#{vip}"
default['bcpc']['consul']['config']['ports']['dns'] = 8600
default['bcpc']['consul']['config']['recursors'] = ["#{vip}"]


# Service definitions reference:
# https://www.consul.io/docs/agent/services.html
default['bcpc']['consul']['services'] = [
  {
    'name' => 'mysql',
    'port' => 3306,
    'enable_tag_override' => true,
    'tags' => ['mysql'],
    'check' => {
      'name' => 'mysql',
      'args' => ['/usr/local/bcpc/bin/mysql-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  },
  {
    'name' => 'haproxy',
    'check' => {
      'name' => 'haproxy',
      'args' => ['/usr/local/bcpc/bin/haproxy-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  },
  {
    'name' => 'dns',
    'check' => {
      'name' => 'dns',
      'args' => ['/usr/local/bcpc/bin/dns-check'],
      'interval' => '10s',
      'timeout' => '2s'
    }
  }
]

# Watch definitions reference:
# https://www.consul.io/docs/agent/watches.html
default['bcpc']['consul']['watches'] = [
  {
    'service' => 'haproxy',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/haproxy-watch']
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/mysql-elect-watch']
  },
  {
    'service' => 'mysql',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/mysql-watch']
  },
  {
    'service' => 'dns',
    'type' => 'checks',
    'args' => ['/usr/local/bcpc/bin/dns-watch']
  }
]
