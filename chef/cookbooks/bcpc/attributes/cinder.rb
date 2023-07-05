###############################################################################
# cinder
###############################################################################

# specify database and configure SQLAlchemy overflow/QueuePool sizes
default['bcpc']['cinder']['db']['dbname'] = 'cinder'
default['bcpc']['cinder']['db']['max_overflow'] = 128
default['bcpc']['cinder']['db']['max_pool_size'] = 64

default['bcpc']['cinder']['debug'] = false
default['bcpc']['cinder']['workers'] = nil
default['bcpc']['cinder']['allow_az_fallback'] = true
default['bcpc']['cinder']['backend_native_threads_pool_size'] = nil
default['bcpc']['cinder']['rbd_exclusive_cinder_pool'] = true
default['bcpc']['cinder']['rbd_flatten_volume_from_snapshot'] = true
default['bcpc']['cinder']['rbd_max_clone_depth'] = 5
default['bcpc']['cinder']['quota'] = {
  'volumes' => -1,
  'snapshots' => 10,
  'gigabytes' => 1000,
}
default['bcpc']['cinder']['qos']['enabled'] = false

# ceph (rbd)
default['bcpc']['cinder']['ceph']['user'] = 'cinder'
default['bcpc']['cinder']['ceph']['pool']['name'] = 'volumes'
default['bcpc']['cinder']['ceph']['pool']['size'] = 3
