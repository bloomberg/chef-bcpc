name             "bcpc"
maintainer       "Bloomberg Finance L.P."
maintainer_email "bcpc@bloomberg.net"
license          "Apache License 2.0"
description      "Installs/Configures Bloomberg Clustered Private Cloud (BCPC)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), '.version'))

depends "apt", ">= 1.9.2"
depends "ubuntu", ">= 1.1.2"
depends "chef-client", ">= 2.2.2"
depends "cron", ">= 1.2.2"
depends "ntp", ">= 1.3.2"
depends "hostsfile", ">= 2.4.5"
depends "concat", ">= 0.3.0"
depends 'bcpc-binary-files', '>= 1.0.0'
depends 'bcpc-prometheus-exporter', '>= 0.1.0'
