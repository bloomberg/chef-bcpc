# rubocop:disable Style/NumericLiterals

default['bcpc']['catalog'] = {
  'identity' => {
    'name' => 'keystone',
    'project' => 'keystone',
    'description' => 'OpenStack Identity',
    'ports' => {
      'admin' => 35357,
      'internal' => 5000,
      'public' => 5000
    },
    'uris' => {
      'admin' => 'v3',
      'internal' => 'v3',
      'public' => 'v3'
    }
  },
  'compute' => {
    'name' => 'nova',
    'project' => 'nova',
    'description' => 'OpenStack Compute Service',
    'ports' => {
      'admin' => 8774,
      'internal' => 8774,
      'public' => 8774
    },
    'uris' => {
      'admin' => 'v2.1/',
      'internal' => 'v2.1/',
      'public' => 'v2.1/'
    }
  },
  'placement' => {
    'name' => 'placement',
    'project' => 'placement',
    'description' => 'Placement API',
    'ports' => {
      'admin' => 8778,
      'internal' => 8778,
      'public' => 8778
    },
    'uris' => {
      'admin' => '',
      'internal' => '',
      'public' => ''
    }
  },
  'volumev3' => {
    'name' => 'cinderv3',
    'project' => 'cinder',
    'description' => 'OpenStack Block Storage v3',
    'ports' => {
      'admin' => 8776,
      'internal' => 8776,
      'public' => 8776
    },
    'uris' => {
      'admin' => 'v3/%(project_id)s',
      'internal' => 'v3/%(project_id)s',
      'public' => 'v3/%(project_id)s'
    }
  },
  'image' => {
    'name' => 'glance',
    'project' => 'glance',
    'description' => 'OpenStack Image Service',
    'ports' => {
      'admin' => 9292,
      'internal' => 9292,
      'public' => 9292
    },
    'uris' => {
      'admin' => '',
      'internal' => '',
      'public' => ''
    }
  },
  'network' => {
    'name' => 'neutron',
    'project' => 'neutron',
    'description' => 'OpenStack Networking',
    'ports' => {
      'admin' => 9696,
      'internal' => 9696,
      'public' => 9696
    },
    'uris' => {
      'admin' => '',
      'internal' => '',
      'public' => ''
    }
  }
}

# rubocop:enable Style/NumericLiterals
