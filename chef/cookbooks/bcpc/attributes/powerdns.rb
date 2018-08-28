###############################################################################
# powerdns
###############################################################################
default['bcpc']['powerdns']['db']['dbname'] = 'pdns'

default['bcpc']['powerdns']['local_address'] = node['ipaddress']
default['bcpc']['powerdns']['local_port'] = 5300
default['bcpc']['powerdns']['security_poll_suffic'] = ''

# domain transfer
default['bcpc']['powerdns']['axfr']['allow_axfr_ips'] = []

# threads
default['bcpc']['powerdns']['receiver_threads'] = 3

# webserver
default['bcpc']['powerdns']['webserver']['address'] = node['ipaddress']
default['bcpc']['powerdns']['webserver']['port'] = 8081
