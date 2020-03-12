###############################################################################
# apache2
###############################################################################

# Explicitly disable HTTP keep-alive for now.  As part of log rotation (or
# when a "systemctl reload apache2" is run), a graceful restart is triggered
# on Ubuntu.  Normally, this is not a problem... however, mod_wsgi in
# particular has an oversight which results in all requests sent to an MPM
# worker from the last generation (i.e., ones serving persistent connections
# prior to a graceful reload) to fail after the graceful restart completes.
default['bcpc']['apache2']['keepalive']['enabled'] = false
default['bcpc']['apache2']['keepalive']['max_requests'] = 100
default['bcpc']['apache2']['keepalive']['timeout'] = 5

# mod_status is a security hazard in production environments
default['bcpc']['apache2']['status']['enabled'] = false

# event mpm module configuration (below are Ubuntu packaging defaults)
default['bcpc']['apache2']['mpm_event']['start_servers'] = 2
default['bcpc']['apache2']['mpm_event']['min_spare_threads'] = 25
default['bcpc']['apache2']['mpm_event']['max_spare_threads'] = 75
default['bcpc']['apache2']['mpm_event']['thread_limit'] = 64
default['bcpc']['apache2']['mpm_event']['threads_per_child'] = 25
default['bcpc']['apache2']['mpm_event']['max_request_workers'] = 150
default['bcpc']['apache2']['mpm_event']['max_connections_per_child'] = 0
