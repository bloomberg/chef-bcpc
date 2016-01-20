###########################################
#
#  Ceph settings for the cluster
#
###########################################
# Trusty is not available at this time for ceph-extras
default['bcpc']['ceph']['extras']['dist'] = "precise"
# To use apache instead of civetweb, make the following value anything but 'civetweb'
default['bcpc']['ceph']['frontend'] = "civetweb"
default['bcpc']['ceph']['chooseleaf'] = "rack"
default['bcpc']['ceph']['pgp_auto_adjust'] = false
# Need to review...
default['bcpc']['ceph']['pgs_per_node'] = 1024
default['bcpc']['ceph']['max_pgs_per_osd'] = 300
# Set to 0 to disable. See http://tracker.ceph.com/issues/8103
default['bcpc']['ceph']['pg_warn_max_obj_skew'] = 10
# Journal size could be 10GB or higher in some cases
default['bcpc']['ceph']['journal_size'] = 2048
# The 'portion' parameters should add up to ~100 across all pools
default['bcpc']['ceph']['default']['replicas'] = 3
default['bcpc']['ceph']['default']['type'] = 'hdd'
default['bcpc']['ceph']['rgw']['replicas'] = 3
default['bcpc']['ceph']['rgw']['portion'] = 33
default['bcpc']['ceph']['rgw']['type'] = 'hdd'
default['bcpc']['ceph']['images']['replicas'] = 3
default['bcpc']['ceph']['images']['portion'] = 33
# Set images to hdd instead of sdd
default['bcpc']['ceph']['images']['type'] = 'hdd'
default['bcpc']['ceph']['images']['name'] = "images"
default['bcpc']['ceph']['volumes']['replicas'] = 3
default['bcpc']['ceph']['volumes']['portion'] = 33
default['bcpc']['ceph']['volumes']['name'] = "volumes"
# Created a new pool for VMs and set type to ssd
default['bcpc']['ceph']['vms']['replicas'] = 3
default['bcpc']['ceph']['vms']['portion'] = 33
default['bcpc']['ceph']['vms']['type'] = 'ssd'
default['bcpc']['ceph']['vms']['name'] = "vms"
# Set up crush rulesets
default['bcpc']['ceph']['ssd']['ruleset'] = 1
default['bcpc']['ceph']['hdd']['ruleset'] = 2

# If you are about to make a big change to the ceph cluster
# setting to true will reduce the load form the resulting
# ceph rebalance and keep things operational.
# See wiki for further details.
default['bcpc']['ceph']['rebalance'] = false

# Set the default niceness of Ceph OSD and monitor processes
default['bcpc']['ceph']['osd_niceness'] = -10
default['bcpc']['ceph']['mon_niceness'] = -10
