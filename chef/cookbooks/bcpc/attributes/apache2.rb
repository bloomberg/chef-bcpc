###############################################################################
# apache2
###############################################################################

# event mpm module (ubuntu packaging defaults)
default['bcpc']['apache2']['mpm_event']['start_servers'] = 2
default['bcpc']['apache2']['mpm_event']['min_spare_threads'] = 25
default['bcpc']['apache2']['mpm_event']['max_spare_threads'] = 75
default['bcpc']['apache2']['mpm_event']['thread_limit'] = 64
default['bcpc']['apache2']['mpm_event']['threads_per_child'] = 25
default['bcpc']['apache2']['mpm_event']['max_request_workers'] = 150
default['bcpc']['apache2']['mpm_event']['max_connections_per_child'] = 0
