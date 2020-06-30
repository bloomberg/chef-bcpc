###############################################################################
# powerdns
###############################################################################
default['bcpc']['powerdns']['db']['dbname'] = 'pdns'

default['bcpc']['powerdns']['local_address'] = node['bcpc']['cloud']['vip']
default['bcpc']['powerdns']['local_port'] = 5300
default['bcpc']['powerdns']['security_poll_suffix'] = ''

# domain transfer
default['bcpc']['powerdns']['axfr']['enabled'] = false
default['bcpc']['powerdns']['axfr']['ips'] = []

# threads
default['bcpc']['powerdns']['receiver_threads'] = 3

# webserver
default['bcpc']['powerdns']['webserver']['address'] = '127.0.0.1'
default['bcpc']['powerdns']['webserver']['port'] = 8081

# name servers
default['bcpc']['powerdns']['nameservers']['ns1'] = node['bcpc']['cloud']['vip']

# also-notify
default['bcpc']['powerdns']['also-notify']['enabled'] = false
default['bcpc']['powerdns']['also-notify']['ips'] = []

# soa ttl
default['bcpc']['powerdns']['soa-ttl']['refresh'] = 600
default['bcpc']['powerdns']['soa-ttl']['retry'] = 300
default['bcpc']['powerdns']['soa-ttl']['expiry'] = 86400
default['bcpc']['powerdns']['soa-ttl']['nx'] = 120

