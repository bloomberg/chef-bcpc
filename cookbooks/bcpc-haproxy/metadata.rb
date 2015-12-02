name             'bcpc-haproxy'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Installs/Configures bcpc-haproxy'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

depends          'apt',             '>= 2.7.0'
depends          'bcpc-foundation', '>= 6.0.0'
depends          'bcpc-xinetd',     '>= 6.0.0'
depends          'concat',          '>= 0.3.0'
