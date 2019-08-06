###############################################################################
# openstack
###############################################################################

default['bcpc']['openstack']['repo']['enabled'] = true
default['bcpc']['openstack']['repo']['url'] = 'http://ubuntu-cloud.archive.canonical.com/ubuntu'

default['bcpc']['openstack']['repo']['release'] = 'rocky'
default['bcpc']['openstack']['repo']['branch'] = 'updates'

default['bcpc']['openstack']['admin']['username'] = 'admin'
default['bcpc']['openstack']['admin']['project'] = 'admin'

default['bcpc']['openstack']['services']['workers'] = nil

###############################################################################
# openstack flavors
###############################################################################

default['bcpc']['openstack']['flavors']['enabled'] = false

default['bcpc']['openstack']['flavors']['generic1.tiny']['vcpus'] = 1
default['bcpc']['openstack']['flavors']['generic1.tiny']['ram'] = 512
default['bcpc']['openstack']['flavors']['generic1.tiny']['disk'] = 1

default['bcpc']['openstack']['flavors']['generic1.small']['vcpus'] = 1
default['bcpc']['openstack']['flavors']['generic1.small']['ram'] = 2048
default['bcpc']['openstack']['flavors']['generic1.small']['disk'] = 20

default['bcpc']['openstack']['flavors']['generic1.medium']['vcpus'] = 2
default['bcpc']['openstack']['flavors']['generic1.medium']['ram'] = 4096
default['bcpc']['openstack']['flavors']['generic1.medium']['disk'] = 40

default['bcpc']['openstack']['flavors']['generic1.large']['vcpus'] = 4
default['bcpc']['openstack']['flavors']['generic1.large']['ram'] = 8192
default['bcpc']['openstack']['flavors']['generic1.large']['disk'] = 40

default['bcpc']['openstack']['flavors']['generic1.xlarge']['vcpus'] = 8
default['bcpc']['openstack']['flavors']['generic1.xlarge']['ram'] = 16384
default['bcpc']['openstack']['flavors']['generic1.xlarge']['disk'] = 40

default['bcpc']['openstack']['flavors']['generic1.2xlarge']['vcpus'] = 16
default['bcpc']['openstack']['flavors']['generic1.2xlarge']['ram'] = 32768
default['bcpc']['openstack']['flavors']['generic1.2xlarge']['disk'] = 40

default['bcpc']['openstack']['flavors']['generic2.small']['vcpus'] = 1
default['bcpc']['openstack']['flavors']['generic2.small']['ram'] = 6144
default['bcpc']['openstack']['flavors']['generic2.small']['disk'] = 50

default['bcpc']['openstack']['flavors']['generic2.medium']['vcpus'] = 2
default['bcpc']['openstack']['flavors']['generic2.medium']['ram'] = 12288
default['bcpc']['openstack']['flavors']['generic2.medium']['disk'] = 100

default['bcpc']['openstack']['flavors']['generic2.large']['vcpus'] = 4
default['bcpc']['openstack']['flavors']['generic2.large']['ram'] = 24576
default['bcpc']['openstack']['flavors']['generic2.large']['disk'] = 100

default['bcpc']['openstack']['flavors']['generic2.xlarge']['vcpus'] = 8
default['bcpc']['openstack']['flavors']['generic2.xlarge']['ram'] = 49152
default['bcpc']['openstack']['flavors']['generic2.xlarge']['disk'] = 100

default['bcpc']['openstack']['flavors']['generic2.2xlarge']['vcpus'] = 16
default['bcpc']['openstack']['flavors']['generic2.2xlarge']['ram'] = 98304
default['bcpc']['openstack']['flavors']['generic2.2xlarge']['disk'] = 100
