###############################################################################
#  neutron
###############################################################################
default['bcpc']['neutron']['debug'] = false
default['bcpc']['neutron']['db']['dbname'] = 'neutron'

# underlying network configuration
default['bcpc']['neutron']['network']['default_network_mtu'] = 1500
default['bcpc']['neutron']['network']['global_physnet_mtu'] = node['bcpc']['networking']['mtu']

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

# calico plugin configuration
default['bcpc']['neutron']['calico']['num_port_status_threads'] = nil
default['bcpc']['neutron']['calico']['etcd_compaction_period_mins'] = nil
default['bcpc']['neutron']['calico']['etcd_compaction_min_revisions'] = nil
default['bcpc']['neutron']['calico']['project_name_cache_max'] = nil

# notifications
default['bcpc']['neutron']['notifications']['enabled'] = false
default['bcpc']['neutron']['notifications']['topics'] = []

# specify keystone_authtoken configs
default['bcpc']['neutron']['keystone_authtoken']['token_cache_time'] = 600
