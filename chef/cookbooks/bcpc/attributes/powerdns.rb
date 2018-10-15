###############################################################################
# powerdns
###############################################################################
default['bcpc']['powerdns']['db']['dbname'] = 'pdns'

default['bcpc']['powerdns']['local_address'] = node['bcpc']['cloud']['vip']
default['bcpc']['powerdns']['local_port'] = 5300
default['bcpc']['powerdns']['security_poll_suffic'] = ''

# domain transfer
default['bcpc']['powerdns']['axfr']['enabled'] = false
default['bcpc']['powerdns']['axfr']['ips'] = []

# threads
default['bcpc']['powerdns']['receiver_threads'] = 3

# webserver
default['bcpc']['powerdns']['webserver']['port'] = 8081
