###############################################################################
# networking
###############################################################################

default['bcpc']['networking']['networks']['primary']['cidr'] = '10.121.84.0/22'
default['bcpc']['networking']['networks']['primary']['interface'] = 'eth1'

default['bcpc']['networking']['racks'] = [
  {
    'id' => 1,
    'bgp' => {
      'tor_as' => 4_200_858_701,
      'node_as' => 4_200_858_701,
    },
    'networks' => {
      'primary' => { 'cidr' => '10.121.84.0/28', 'gateway' => '10.121.84.1' },
    },
  },
  {
    'id' => 2,
    'bgp' => {
      'tor_as' => 4_200_858_702,
      'node_as' => 4_200_858_702,
    },
    'networks' => {
      'primary' => { 'cidr' => '10.121.85.0/28', 'gateway' => '10.121.85.1' },
    },
  },
  {
    'id' => 3,
    'bgp' => {
      'tor_as' => 4_200_858_703,
      'node_as' => 4_200_858_703,
    },
    'networks' => {
      'primary' => { 'cidr' => '10.121.86.0/28', 'gateway' => '10.121.86.1' },
    },
  },
]
