###############################################################################
# openstack
###############################################################################

default['bcpc']['openstack']['repo']['enabled'] = false
default['bcpc']['openstack']['repo']['url'] = 'http://ubuntu-cloud.archive.canonical.com/ubuntu'

default['bcpc']['openstack']['repo']['release'] = 'queens'
default['bcpc']['openstack']['repo']['branch'] = 'updates'

default['bcpc']['openstack']['admin']['username'] = 'admin'
default['bcpc']['openstack']['admin']['project'] = 'admin'
