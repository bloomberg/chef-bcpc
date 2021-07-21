###############################################################################
# placement
###############################################################################

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['placement']['db']['dbname'] = 'placement'
default['bcpc']['placement']['db']['max_overflow'] = 128
default['bcpc']['placement']['db']['max_pool_size'] = 64

# Placement debug toggle
default['bcpc']['placement']['debug'] = false

# "workers" parameters in nova are set to number of CPUs
# available by default. This provides an override.
default['bcpc']['placement']['workers'] = nil
default['bcpc']['placement']['workers'] = nil

# Placement default log levels
default['bcpc']['placement']['default_log_levels'] = nil
