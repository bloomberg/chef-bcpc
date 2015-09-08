name             'bcpc-binary-files'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache 2.0'
description      'This cookbook has no recipes and serves only to encapsulate all binary files used by BCPC cookbooks.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '6.0.0'

depends          'bcpc-foundation', '>= 6.0.0'
