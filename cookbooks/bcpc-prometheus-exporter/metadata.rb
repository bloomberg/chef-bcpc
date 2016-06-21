name             'bcpc-prometheus-exporter'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'bcpc@bloomberg.net'
license          'Apache License 2.0'
description      'Prometheus exporters used by BCPC'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'
issues_url       'https://github.com/bloomberg/chef-bcpc/issues'
source_url       'https://github.com/bloomberg/chef-bcpc'

depends          'logrotate', '>= 1.9.2'
depends          'bcpc', '>= 5.12.0'
depends          'bcpc-binary-files', '>= 1.0.0'
