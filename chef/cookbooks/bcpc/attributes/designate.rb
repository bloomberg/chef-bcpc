###############################################################################
# designate
###############################################################################

# logging
default['bcpc']['designate']['debug'] = false

# database
default['bcpc']['designate']['db']['dbname'] = 'designate'

# default pool. the "." at the end of the hostname value must be there
# to be considered a valid domainname
default['bcpc']['designate']['pool']['description'] = 'Default pool'
default['bcpc']['designate']['pool']['ns_records'] = [
  {
    "hostname": "ns1.#{node['bcpc']['cloud']['domain']}.",
    "priority": 1,
  },
]

# List of additional IP/Port's for which designate-mdns will send
# DNS NOTIFY packets to
default['bcpc']['designate']['also_notifies'] = []
