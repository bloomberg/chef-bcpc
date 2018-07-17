###############################################################################
# networking
###############################################################################

default['bcpc']['networking']['networks']['primary']['cidr'] = '10.121.84.0/22'
default['bcpc']['networking']['networks']['primary']['interface'] = 'eth1'

default['bcpc']['networking']['networks']['storage']['cidr'] = '10.121.88.0/22'
default['bcpc']['networking']['networks']['storage']['interface'] = 'eth2'
default['bcpc']['networking']['networks']['storage']['vlan'] = 1337
default['bcpc']['networking']['networks']['storage']['mtu'] = 9000

default['bcpc']['networking']['racks'] = [
  {
    'id' => 1,
    'pod' => 'a',
    'bgp_as' => 4_200_858_701,
    'networks' => {
      'primary' => { 'cidr' => '10.121.84.0/28', 'gateway' => '10.121.84.1' },
      'storage' => { 'cidr' => '10.121.88.0/28', 'gateway' => '10.121.88.1' }
    }
  },
  {
    'id' => 2,
    'pod' => 'a',
    'bgp_as' => 4_200_858_702,
    'networks' => {
      'primary' => { 'cidr' => '10.121.85.0/28', 'gateway' => '10.121.85.1' },
      'storage' => { 'cidr' => '10.121.89.0/28', 'gateway' => '10.121.89.1' }
    }
  },
  {
    'id' => 3,
    'pod' => 'a',
    'bgp_as' => 4_200_858_703,
    'networks' => {
      'primary' => { 'cidr' => '10.121.86.0/28', 'gateway' => '10.121.86.1' },
      'storage' => { 'cidr' => '10.121.90.0/28', 'gateway' => '10.121.90.1' }
    }
  }
]
