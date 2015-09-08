name             'component-bcpc-common'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Role cookbook for shared recipes across all BCPC nodes'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

conflicts        'bcpc'
depends          'chef-client',     '>= 4.3.1'
depends          'ntp',             '>= 1.8.6'
depends          'ubuntu',          '>= 1.1.8'
depends          'bcpc-foundation', '>= 6.0.0'
depends          'bcpc-getty',      '>= 6.0.0'
