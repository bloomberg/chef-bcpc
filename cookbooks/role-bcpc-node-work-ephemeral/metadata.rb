name             'role-bcpc-node-work-ephemeral'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'Installs/Configures role-bcpc-node-work-ephemeral'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

depends          'component-bcpc-common',           '>= 6.0.0'
depends          'component-bcpc-node-common',      '>= 6.0.0'
depends          'component-bcpc-node-work-common', '>= 6.0.0'
depends          'bcpc-ephemeral-disk',        '>= 6.0.0'
depends          'component-bcpc-node-monitoring', '>= 6.0.0'
