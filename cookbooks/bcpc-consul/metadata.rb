name             'bcpc-consul'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache-2.0'
description      'Installs/Configures Consul for BCPC'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
issues_url       'https://github.com/bloomberg/chef-bcpc/issues'
source_url       'https://github.com/bloomberg/chef-bcpc'
version          '0.0.1'

chef_version     '>= 12.3'

supports 'ubuntu', '>= 14.04'

depends 'bcpc', '>= 7.0.0'
depends 'bcpc-binary-files', '>= 6.0.1'
