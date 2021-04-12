###############################################################################
# nova
###############################################################################

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['nova']['db']['dbname'] = 'nova'
default['bcpc']['nova']['db']['max_overflow'] = 128
default['bcpc']['nova']['db']['max_pool_size'] = 64

# Nova debug toggle
default['bcpc']['nova']['debug'] = false

# ceph (rbd)
default['bcpc']['nova']['ceph']['user'] = 'nova'
default['bcpc']['nova']['ceph']['pool']['name'] = 'vms'
default['bcpc']['nova']['ceph']['pool']['size'] = 1

# Defines which physical CPUs (pCPUs) can be used by instance virtual CPUs
default['bcpc']['nova']['vcpu_pin_set'] = nil

# Over-allocation settings. Set according to your cluster
# SLAs. Default is to not allow over allocation of memory
# a slight over allocation of CPU (x2).
default['bcpc']['nova']['ram_allocation_ratio'] = 1.0
default['bcpc']['nova']['reserved_host_memory_mb'] = 1024
default['bcpc']['nova']['cpu_allocation_ratio'] = 2.0

# nova/oslo notification settings
default['bcpc']['nova']['notifications']['topics'] = 'notifications'
default['bcpc']['nova']['notifications']['driver'] = 'messagingv2'
default['bcpc']['nova']['notifications']['notify_on_state_change'] = 'vm_and_task_state'

# CPU passthrough/masking configurations
default['bcpc']['nova']['cpu_config']['AuthenticAMD']['cpu_mode'] = 'custom'
default['bcpc']['nova']['cpu_config']['AuthenticAMD']['cpu_model'] = 'qemu64'
default['bcpc']['nova']['cpu_config']['AuthenticAMD']['cpu_model_extra_flags'] = []
default['bcpc']['nova']['cpu_config']['GenuineIntel']['cpu_mode'] = 'custom'
default['bcpc']['nova']['cpu_config']['GenuineIntel']['cpu_model'] = 'qemu64'
default['bcpc']['nova']['cpu_config']['GenuineIntel']['cpu_model_extra_flags'] = []

# select from between this many equally optimal hosts when launching an instance
default['bcpc']['nova']['scheduler_host_subset_size'] = 3

# maximum number of builds to allow the scheduler to run simultaneously
# (setting too high may cause Three Stooges Syndrome, particularly on RBD-intensive operations)
default['bcpc']['nova']['max_concurrent_builds'] = 4

# "workers" parameters in nova are set to number of CPUs
# available by default. This provides an override.
default['bcpc']['nova']['workers'] = nil
default['bcpc']['placement']['workers'] = nil

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

# per-project override quota settings
#
default['bcpc']['nova']['quota']['project']['admin']['ram'] = -1
default['bcpc']['nova']['quota']['project']['admin']['floating-ips'] = -1
default['bcpc']['nova']['quota']['project']['admin']['cores'] = -1
default['bcpc']['nova']['quota']['project']['admin']['instances'] = -1
default['bcpc']['nova']['quota']['project']['admin']['ports'] = -1
default['bcpc']['nova']['quota']['project']['admin']['gigabytes'] = -1

# metadata API
#
default['bcpc']['nova']['vendordata']['name'] = nil
default['bcpc']['nova']['vendordata']['port'] = 8444

# nova db archive deleted rows
#

# is nova db archive enabled
default['bcpc']['nova']['db-archive']['enabled'] = false

# if enabled, what is the schedule to run
default['bcpc']['nova']['db-archive']['cron_month'] = '*'
default['bcpc']['nova']['db-archive']['cron_day'] = '*'
default['bcpc']['nova']['db-archive']['cron_weekday'] = '6'
default['bcpc']['nova']['db-archive']['cron_hour'] = '4'
default['bcpc']['nova']['db-archive']['cron_minute'] = '0'

# Anti-affinity availability zone scheduler filter
default['bcpc']['nova']['scheduler']['filter']['anti_affinity_availability_zone']['enabled'] = false
default['bcpc']['nova']['scheduler']['filter']['anti_affinity_availability_zone']['name'] = 'AntiAffinityAvailabilityZoneFilter'
default['bcpc']['nova']['scheduler']['filter']['anti_affinity_availability_zone']['filterPath'] = 'nova.scheduler.filters.anti_affinity_availability_zone_filter.AntiAffinityAvailabilityZoneFilter'
