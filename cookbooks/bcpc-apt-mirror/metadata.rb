name             'bcpc-apt-mirror'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Installs/Configures bcpc-apt-mirror'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

conflicts        'bcpc-apache'
depends          'bcpc-bootstrap',  '>= 6.0.0'
depends          'bcpc-foundation', '>= 6.0.0'
