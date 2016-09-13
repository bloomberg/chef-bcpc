name             'bcpc_common'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache License 2.0'
description      'Installs components common to all BCPC nodes'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'
issues_url       'https://github.com/bloomberg/chef-bcpc/issues'
source_url       'https://github.com/bloomberg/chef-bcpc'

depends 'apt', '>= 3.0.0'
depends 'chef-client', '>= 4.5.0'
depends 'ntp', '>= 2.0.0'
depends 'ubuntu', '>= 1.2.0'
