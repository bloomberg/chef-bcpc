###############################################################################
#  neutron
###############################################################################

default['bcpc']['neutron']['debug'] = false
default['bcpc']['neutron']['db']['dbname'] = 'neutron'

# networks
#
default['bcpc']['neutron']['network']['ext1'] = {
  "subnets": [
    {"name": "primary", "cidr": "10.64.0.0/18"}
  ]
}

default['bcpc']['neutron']['network']['ext2'] = {
  "subnets": [
    {"name": "primary", "cidr": "10.65.0.0/18"}
  ]
}
