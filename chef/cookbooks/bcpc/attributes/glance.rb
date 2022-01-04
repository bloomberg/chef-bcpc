###############################################################################
# glance
###############################################################################

default['bcpc']['glance']['debug'] = false
default['bcpc']['glance']['workers'] = nil

# database
default['bcpc']['glance']['db']['dbname'] = 'glance'
default['bcpc']['glance']['db']['username'] = 'glance'
default['bcpc']['glance']['db']['max_overflow'] = 128
default['bcpc']['glance']['db']['max_pool_size'] = 64

# openstack
default['bcpc']['glance']['os']['username'] = 'glance'

# ceph (rbd)
default['bcpc']['glance']['ceph']['user'] = 'glance'
default['bcpc']['glance']['ceph']['pool']['name'] = 'images'
default['bcpc']['glance']['ceph']['pool']['size'] = 3

# image format
default['bcpc']['glance']['image_format']['container_formats'] = ['bare']
default['bcpc']['glance']['image_format']['disk_formats'] = ['raw']
