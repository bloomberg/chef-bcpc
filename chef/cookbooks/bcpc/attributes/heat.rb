###############################################################################
# heat
###############################################################################

default['bcpc']['heat']['enabled'] = true

# database
default['bcpc']['heat']['db']['dbname'] = 'heat'
default['bcpc']['heat']['database']['max_overflow'] = 128
default['bcpc']['heat']['database']['max_pool_size'] = 64

# workers parameters for heat-api and heat-engine set to number of CPUs
# available by default. This provides an override.
default['bcpc']['heat']['api_workers'] = nil
default['bcpc']['heat']['engine_workers'] = nil
