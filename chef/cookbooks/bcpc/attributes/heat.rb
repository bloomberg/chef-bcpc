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

# Maximum depth allowed when using nested stacks/templates. Currently, this
# defaults to 5 upstream, which can be exceeded with sufficiently complex
# templates. Bumping this from 5 to 8 provides sufficient headroom.
default['bcpc']['heat']['max_nested_stack_depth'] = 8

# specify keystone_authtoken configs
default['bcpc']['heat']['keystone_authtoken']['token_cache_time'] = 600
