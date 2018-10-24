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
    'fixed' => {
      'dns-zones' => { 'create' => true, 'fqdn-prefix' => 'ext1' },
      'subnets' => [
        { 'allocation' => '10.64.0.0/24' },
      ],
    },
    'float' => {
      'dns-zones' => { 'create' => true, 'fqdn-prefix' => 'ext1-float' },
      'subnets' => [
        { 'allocation' => '10.64.1.0/24' },
      ],
    },
  },
]
