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
