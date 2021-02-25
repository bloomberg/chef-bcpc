###############################################################################
# heat
###############################################################################

default['bcpc']['heat']['enabled'] = true

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['heat']['db']['dbname'] = 'heat'
default['bcpc']['heat']['db']['max_overflow'] = 128
default['bcpc']['heat']['db']['max_pool_size'] = 64

# workers parameters for heat-api and heat-engine set to number of CPUs
# available by default. This provides an override.
default['bcpc']['heat']['api_workers'] = nil
default['bcpc']['heat']['engine_workers'] = nil
