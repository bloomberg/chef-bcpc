maintainer       "Bloomberg Finance L.P."
maintainer_email "rrichardson6@bloomberg.net"
license          "Apache License 2.0"
description      "Installs/Configures Bloomberg Clustered Private Hadoop Cloud (BCPHC)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

depends "bcpc", ">= 0.5.0"
depends "dpkg_autostart"
