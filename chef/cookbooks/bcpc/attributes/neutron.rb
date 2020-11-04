###############################################################################
#  neutron
###############################################################################
default['bcpc']['neutron']['debug'] = false
default['bcpc']['neutron']['db']['dbname'] = 'neutron'

# neutron network nameservers
# this list is used during the neutron subnet creation process to set the
# dns-namserver for the instances
default['bcpc']['neutron']['network']['nameservers'] = [node['bcpc']['cloud']['vip']]

default['bcpc']['neutron']['workers'] = nil

# networks
default['bcpc']['neutron']['networks'] = [
  {
    'name' => 'ext1',
    'fixed' => {
      'dns-zones' => { 'create' => true, 'fqdn-prefix' => 'ext1' },
      'subnets' => [
        { 'allocation' => '10.1.0.0/24' },
      ],
    },
    'float' => {
      'dns-zones' => { 'create' => true, 'fqdn-prefix' => 'ext1-float' },
      'subnets' => [
        { 'allocation' => '10.1.1.0/24' },
      ],
    },
  },
]

# default quota settings
default['bcpc']['neutron']['quota']['default']['quota_floatingip'] = 0

# per-project quota settings
default['bcpc']['neutron']['quota']['project']['admin']['rbac-policies'] = -1

# database connection pool settings
default['bcpc']['neutron']['db']['max_pool_size'] = 64
default['bcpc']['neutron']['db']['max_overflow'] = 128
