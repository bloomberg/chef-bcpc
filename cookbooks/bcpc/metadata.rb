name             "bcpc"
maintainer       "Bloomberg Finance L.P."
maintainer_email "bcpc@bloomberg.net"
license          "Apache License 2.0"
description      "Installs/Configures Bloomberg Clustered Private Cloud (BCPC)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), '.version'))
issues_url       'https://github.com/bloomberg/chef-bcpc/issues'
source_url       'https://github.com/bloomberg/chef-bcpc'

depends "apt", ">= 3.0.0"
depends "ubuntu", ">= 1.2.0"
depends "chef-client", ">= 4.5.0"
depends "cron", ">= 1.7.6"
depends "ntp", ">= 2.0.0"
depends "hostsfile", ">= 2.4.5"
depends "concat", ">= 0.3.3"
depends 'bcpc-binary-files', '>= 6.0.0'
depends 'logrotate', '>= 1.9.2'
