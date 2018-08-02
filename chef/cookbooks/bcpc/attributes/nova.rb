###############################################################################
# nova
###############################################################################

# database
default['bcpc']['nova']['db']['dbname'] = 'nova'

# Nova debug toggle
default['bcpc']['nova']['debug'] = false

# ceph (rbd)
default['bcpc']['nova']['ceph']['user'] = 'cinder'
default['bcpc']['nova']['ceph']['pool']['name'] = 'vms'
default['bcpc']['nova']['ceph']['pool']['size'] = 1

# Over-allocation settings. Set according to your cluster
# SLAs. Default is to not allow over allocation of memory
# a slight over allocation of CPU (x2).
default['bcpc']['nova']['ram_allocation_ratio'] = 1.0
default['bcpc']['nova']['reserved_host_memory_mb'] = 1024
default['bcpc']['nova']['cpu_allocation_ratio'] = 2.0

# nova/oslo notification settings
default['bcpc']['nova']['notifications']['topics'] = 'notifications'
default['bcpc']['nova']['notifications']['driver'] = 'messagingv2'
default['bcpc']['nova']['notifications']['notify_on_state_change'] = 'vm_state'

# CPU passthrough/masking configurations
default['bcpc']['nova']['cpu_config']['cpu_mode'] = 'none'
default['bcpc']['nova']['cpu_config']['cpu_model'] = 'none'

# select from between this many equally optimal hosts when launching an instance
default['bcpc']['nova']['scheduler_host_subset_size'] = 3

# maximum number of builds to allow the scheduler to run simultaneously
# (setting too high may cause Three Stooges Syndrome, particularly on RBD-intensive operations)
default['bcpc']['nova']['max_concurrent_builds'] = 4

# "workers" parameters in nova are set to number of CPUs
# available by default. This provides an override.
default['bcpc']['nova']['workers'] = 5

# configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['nova']['database']['max_overflow'] = 10
default['bcpc']['nova']['database']['max_pool_size'] = 5

# set soft/hard ulimits in upstart unit file for nova-compute
# as number of OSDs in cluster increases, soft limit needs to increase to avoid
# nova-compute deadlocks
default['bcpc']['nova']['compute']['limits']['nofile']['soft'] = 1024
default['bcpc']['nova']['compute']['limits']['nofile']['hard'] = 4096

# frequency of syncing power states between hypervisor and database
default['bcpc']['nova']['sync_power_state_interval'] = 600

# automatically restart guests that were running when hypervisor was rebooted
default['bcpc']['nova']['resume_guests_state_on_host_boot'] = false

# Nova default log levels
default['bcpc']['nova']['default_log_levels'] = nil

# The loopback address matches what Calico's Felix defaults to for metadata
default['bcpc']['nova']['metadata_listen'] = '127.0.0.1'

# Nova scheduler default filters
default['bcpc']['nova']['scheduler_default_filters'] = %w(
  AggregateInstanceExtraSpecsFilter
  RetryFilter
  AvailabilityZoneFilter
  CoreFilter
  RamFilter
  DiskFilter
  ComputeFilter
  ComputeCapabilitiesFilter
  NUMATopologyFilter
  ImagePropertiesFilter
  ServerGroupAntiAffinityFilter
  ServerGroupAffinityFilter
)

# flavors
#
default['bcpc']['nova']['flavors']['generic1.tiny']['vcpus'] = 1
default['bcpc']['nova']['flavors']['generic1.tiny']['ram'] = 512
default['bcpc']['nova']['flavors']['generic1.tiny']['disk'] = 1

default['bcpc']['nova']['flavors']['generic1.small']['vcpus'] = 1
default['bcpc']['nova']['flavors']['generic1.small']['ram'] = 2048
default['bcpc']['nova']['flavors']['generic1.small']['disk'] = 20

default['bcpc']['nova']['flavors']['generic1.medium']['vcpus'] = 2
default['bcpc']['nova']['flavors']['generic1.medium']['ram'] = 4096
default['bcpc']['nova']['flavors']['generic1.medium']['disk'] = 40

default['bcpc']['nova']['flavors']['generic1.large']['vcpus'] = 4
default['bcpc']['nova']['flavors']['generic1.large']['ram'] = 8192
default['bcpc']['nova']['flavors']['generic1.large']['disk'] = 40

default['bcpc']['nova']['flavors']['generic1.xlarge']['vcpus'] = 8
default['bcpc']['nova']['flavors']['generic1.xlarge']['ram'] = 16384
default['bcpc']['nova']['flavors']['generic1.xlarge']['disk'] = 40

default['bcpc']['nova']['flavors']['generic1.2xlarge']['vcpus'] = 16
default['bcpc']['nova']['flavors']['generic1.2xlarge']['ram'] = 32768
default['bcpc']['nova']['flavors']['generic1.2xlarge']['disk'] = 40

default['bcpc']['nova']['flavors']['generic2.small']['vcpus'] = 1
default['bcpc']['nova']['flavors']['generic2.small']['ram'] = 6144
default['bcpc']['nova']['flavors']['generic2.small']['disk'] = 50

default['bcpc']['nova']['flavors']['generic2.medium']['vcpus'] = 2
default['bcpc']['nova']['flavors']['generic2.medium']['ram'] = 12288
default['bcpc']['nova']['flavors']['generic2.medium']['disk'] = 100

default['bcpc']['nova']['flavors']['generic2.large']['vcpus'] = 4
default['bcpc']['nova']['flavors']['generic2.large']['ram'] = 24576
default['bcpc']['nova']['flavors']['generic2.large']['disk'] = 100

default['bcpc']['nova']['flavors']['generic2.xlarge']['vcpus'] = 8
default['bcpc']['nova']['flavors']['generic2.xlarge']['ram'] = 49152
default['bcpc']['nova']['flavors']['generic2.xlarge']['disk'] = 100
default['bcpc']['nova']['flavors']['generic2.2xlarge']['vcpus'] = 16
default['bcpc']['nova']['flavors']['generic2.2xlarge']['ram'] = 98304
default['bcpc']['nova']['flavors']['generic2.2xlarge']['disk'] = 100

# default quota
#
default['bcpc']['nova']['quota']['global']['cores'] = -1
default['bcpc']['nova']['quota']['global']['ram'] = -1
default['bcpc']['nova']['quota']['global']['floating-ips'] = -1

# per-project override quota settings
#
default['bcpc']['nova']['quota']['project']['admin']['cores'] = -1
default['bcpc']['nova']['quota']['project']['admin']['ram'] = -1
default['bcpc']['nova']['quota']['project']['admin']['floating-ips'] = -1
