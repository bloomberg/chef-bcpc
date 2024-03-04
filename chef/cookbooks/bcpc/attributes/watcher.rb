###############################################################################
# watcher
###############################################################################

default['bcpc']['watcher']['enabled'] = false

# database
default['bcpc']['watcher']['db']['dbname'] = 'watcher'

default['bcpc']['watcher']['api_workers'] = nil

# specify keystone_authtoken configs
default['bcpc']['watcher']['keystone_authtoken']['token_cache_time'] = 600
