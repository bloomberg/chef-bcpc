###############################################################################
# Memcached
###############################################################################

# Enable memcached double verbose logging.
default['bcpc']['memcached']['debug'] = false

# Set number of memcached connections.
default['bcpc']['memcached']['connections'] = 10240

# Specifies memcached maximum limit of RAM to use for item
# storage (in megabytes). Note carefully that this isn't a global memory limit
default['bcpc']['memcached']['memory'] = 64
