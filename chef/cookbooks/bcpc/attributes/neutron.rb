###############################################################################
#  neutron
###############################################################################

default['bcpc']['neutron']['debug'] = false
default['bcpc']['neutron']['db']['dbname'] = 'neutron'

# networks
#
default['bcpc']['neutron']['networks'] = [
  {
    'name' => 'ext1',
    'fixed' => [
      { 'cidr' => '10.64.0.0/16' },
    ],
    'float' => [
      { 'cidr' => '10.65.0.0/16' },
    ],
  },
]
