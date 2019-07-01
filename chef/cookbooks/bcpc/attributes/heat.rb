###############################################################################
# heat
###############################################################################

default['bcpc']['heat']['enabled'] = true

# database
default['bcpc']['heat']['db']['dbname'] = 'heat'
default['bcpc']['heat']['database']['max_overflow'] = 10
default['bcpc']['heat']['database']['max_pool_size'] = 5

# workers parameters for heat-api and heat-engine set to number of CPUs
# available by default. This provides an override.
default['bcpc']['heat']['api_workers'] = 1
default['bcpc']['heat']['engine_workers'] = 1
