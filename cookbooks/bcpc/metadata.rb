maintainer       "Bloomberg Finance L.P."
maintainer_email "pchandra7@bloomberg.net"
license          "Apache License 2.0"
description      "Installs/Configures Bloomberg Clustered Private Cloud (BCPC)"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.5.0"

depends "apt", ">= 1.9.2"
depends "ubuntu", ">= 1.1.2"
depends "chef-client", ">= 2.2.2"
depends "cron", ">= 1.2.2"
depends "ntp", ">= 1.3.2"
depends "python"
