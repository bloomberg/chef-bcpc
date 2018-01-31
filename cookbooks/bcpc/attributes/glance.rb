###########################################
#
#  Glance Settings
#
###########################################
# Verbose logging (level INFO)
default['bcpc']['glance']['verbose'] = false
default['bcpc']['glance']['debug'] = false
default['bcpc']['glance']['workers'] = 5
default['bcpc']['glance']['database']['max_overflow'] = 10
default['bcpc']['glance']['database']['max_pool_size'] = 5

# This may need to be rescoped...
default['bcpc']['glance']['user'] = 'glance'
default['bcpc']['glance']['days_to_keep_logs'] = 14