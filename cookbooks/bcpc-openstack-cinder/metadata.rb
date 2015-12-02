name             'bcpc-openstack-cinder'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Installs/Configures bcpc-openstack-cinder'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

depends          'bcpc-foundation',         '>= 6.0.0'
depends          'bcpc-mysql',              '>= 6.0.0'
depends          'bcpc-ceph',               '>= 6.0.0'
depends          'bcpc-openstack-common',   '>= 6.0.0'
depends          'bcpc-openstack-keystone', '>= 6.0.0'
