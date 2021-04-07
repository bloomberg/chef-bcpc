###############################################################################
# placement
###############################################################################

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['placement']['db']['dbname'] = 'placement'
default['bcpc']['placement']['db']['max_overflow'] = 128
default['bcpc']['placement']['db']['max_pool_size'] = 64

# Nova debug toggle
# TODO: @tstachecki: implement
default['bcpc']['placement']['debug'] = false

# ceph (rbd)
default['bcpc']['placement']['ceph']['user'] = 'nova'
default['bcpc']['placement']['ceph']['pool']['name'] = 'vms'
default['bcpc']['placement']['ceph']['pool']['size'] = 1

# Defines which physical CPUs (pCPUs) can be used by instance virtual CPUs
default['bcpc']['placement']['vcpu_pin_set'] = nil

# Over-allocation settings. Set according to your cluster
# SLAs. Default is to not allow over allocation of memory
# a slight over allocation of CPU (x2).
default['bcpc']['placement']['ram_allocation_ratio'] = 1.0
default['bcpc']['placement']['reserved_host_memory_mb'] = 1024
default['bcpc']['placement']['cpu_allocation_ratio'] = 2.0

# nova/oslo notification settings
# TODO: @tstachecki:  do we just use nova's?
default['bcpc']['placement']['notifications']['topics'] = 'notifications'
default['bcpc']['placement']['notifications']['driver'] = 'messagingv2'

# maximum number of builds to allow the scheduler to run simultaneously
# (setting too high may cause Three Stooges Syndrome, particularly on RBD-intensive operations)
default['bcpc']['placement']['max_concurrent_builds'] = 4

# "workers" parameters in nova are set to number of CPUs
# available by default. This provides an override.
default['bcpc']['placement']['workers'] = nil
default['bcpc']['placement']['workers'] = nil

# Nova default log levels
# TODO: @tstachecki: implement
default['bcpc']['placement']['default_log_levels'] = nil
