name             "bcpc"
maintainer       "Bloomberg Finance L.P."
maintainer_email "bcpc@bloomberg.net"
license          "Apache License 2.0"
description      "Installs/Configures Bloomberg Clustered Private Cloud (BCPC)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), '.version'))

depends "logrotate", ">= 2.2.0"
