name             'bcpc-foundation'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'bcpc-foundation provides a set of recipes common to all BCPC nodes, primarily configuring the operating system and Chef client.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

conflicts        'bcpc'
depends          'apt', '>= 2.7.0'
