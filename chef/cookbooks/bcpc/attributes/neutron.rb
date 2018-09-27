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
      {
        'allocation' => '10.64.0.0/16',
        'dns' => {
          'hostname_prefix' => 'ext1',
          'reverse_zone' => '64.10.in-addr.arpa',
        },
      },
    ],
    'float' => [
      {
        'allocation' => '10.65.0.0/16',
        'dns' => {
          'hostname_prefix' => 'float',
          'reverse_zone' => '65.10.in-addr.arpa',
        },
      },
    ],
  },
]
