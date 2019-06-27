name             'bcpc'
source_url       'https://github.com/bloomberg/chef-bcpc'
issues_url       'https://github.com/bloomberg/chef-bcpc/issues'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache-2.0'
supports         'ubuntu'
description      'Installs/Configures Bloomberg Clustered Private Cloud (BCPC)'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), '.version'))
chef_version     '~> 14'

depends 'logrotate', '>= 2.2.0'
