###########################################
#
#  Nova Settings
#
###########################################
#
# Over-allocation settings. Set according to your cluster
# SLAs. Default is to not allow over allocation of memory
# a slight over allocation of CPU (x2).
default['bcpc']['nova']['ram_allocation_ratio'] = 1.0
default['bcpc']['nova']['reserved_host_memory_mb'] = 1024
default['bcpc']['nova']['cpu_allocation_ratio'] = 2.0
# CPU passthrough/masking configurations
default['bcpc']['nova']['cpu_config']['cpu_mode'] = nil
default['bcpc']['nova']['cpu_config']['cpu_model'] = nil
default['bcpc']['nova']['cpu_config']['vcpu_pin_set'] = nil
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
# rpc timeout
default['bcpc']['nova']['rpc_response_timeout'] = 120
# whether to enable services by default (e.g. for new compute nodes)
default['bcpc']['nova']['enable_new_services'] = true
# whether to force config drive usage
default['bcpc']['nova']['force_config_drive'] = false
# set soft/hard ulimits in upstart unit file for nova-compute
# as number of OSDs in cluster increases, soft limit needs to increase to avoid
# nova-compute deadlocks
default['bcpc']['nova']['compute']['limits']['nofile']['soft'] = 16384
default['bcpc']['nova']['compute']['limits']['nofile']['hard'] = 16384
# frequency of syncing power states between hypervisor and database
default['bcpc']['nova']['sync_power_state_interval'] = 600
# automatically restart guests that were running when hypervisor was rebooted
default['bcpc']['nova']['resume_guests_state_on_host_boot'] = false
# Verbose logging (level INFO)
default['bcpc']['nova']['verbose'] = false
# Nova debug toggle
default['bcpc']['nova']['debug'] = false
# Nova default log levels
default['bcpc']['nova']['default_log_levels'] = nil
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

# Identity
default['bcpc']['nova']['user'] = 'nova'

# configure optional Nova notification system
default['bcpc']['nova']['notifications']['enabled'] = false
default['bcpc']['nova']['notifications']['notification_topics'] = 'notifications'
default['bcpc']['nova']['notifications']['notification_driver'] = 'messagingv2'
default['bcpc']['nova']['notifications']['notify_on_state_change'] = 'vm_state'

default['bcpc']['nova']['quota'] = {
  "cores" => 4,
  "floating_ips" => 10,
  "gigabytes"=> 1000,
  "instances" => -1,
  "ram" => 8192
}

# Conditionally forwards queries to external DNS servers.
# When false, all DNS queries will be resolved via nameservers defined in
# /etc/resolv.conf.
# When true, all DNS queries will be forwarded to external DNS servers
# by each tenant's dnsmasq instance, except fixed zone PTRs.
default['bcpc']['nova']['conditional_dns'] = false

default['bcpc']['nova']['days_to_keep_logs'] = 14
