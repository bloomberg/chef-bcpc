name             'bcpc-centos'
maintainer       'Bloomberg, L.P.'
maintainer_email 'clongo3@bloomberg.net'
license          "Apache License 2.0"
description      'Installs/Configures CentOS hosts for use in Hadoop clusters'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.3.0'

depends "bcpc", ">= 0.4.0"
depends "yum", ">= 2.3.0"
