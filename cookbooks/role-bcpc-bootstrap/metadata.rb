name             'role-bcpc-bootstrap'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Role cookbook for BCPC bootstrap nodes'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

conflicts        'bcpc'
depends          'component-bcpc-common', '>= 6.0.0'
depends          'bcpc-bootstrap',        '>= 6.0.0'
depends          'bcpc-openstack-rally',  '>= 6.0.0'
