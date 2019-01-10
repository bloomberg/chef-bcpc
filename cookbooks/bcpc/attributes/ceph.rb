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
default['bcpc']['ceph']['pgs_per_node'] = 128
default['bcpc']['ceph']['max_pgs_per_osd'] = 300
default['bcpc']['ceph']['osd_scrub_load_threshold'] = 0.5
# Help minimize scrub influence on cluster performance
default['bcpc']['ceph']['osd_scrub_begin_hour'] = 21
default['bcpc']['ceph']['osd_scrub_end_hour'] = 10
default['bcpc']['ceph']['osd_scrub_sleep'] = 0.1
default['bcpc']['ceph']['osd_scrub_chunk_min'] = 1
default['bcpc']['ceph']['osd_scrub_chunk_max'] = 5
# Set to 0 to disable. See http://tracker.ceph.com/issues/8103
default['bcpc']['ceph']['pg_warn_max_obj_skew'] = 10
# Journal size could be 10GB or higher in some cases
default['bcpc']['ceph']['journal_size'] = 2048
# The 'portion' parameters should add up to ~100 across all pools
default['bcpc']['ceph']['default']['replicas'] = 3
default['bcpc']['ceph']['default']['type'] = 'hdd'
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

# Set the default niceness of Ceph OSD and monitor processes
default['bcpc']['ceph']['osd_niceness'] = -10
default['bcpc']['ceph']['mon_niceness'] = -10

# set the following 2 parameters to true to reduce
# osds primary affinity to 0 on headnodes
default['bcpc']['ceph']['allow_primary_affinity'] = true
default['bcpc']['ceph']['set_headnode_affinity'] = true

# set tcmalloc max total thread cache
default['bcpc']['ceph']['tcmalloc_max_total_thread_cache_bytes'] = '128MB'

# expected tunables when running ceph osd crush show-tunables
# any deviation from these settings will stop the recipe from
# reapplying optimal tunables
default['bcpc']['ceph']['expected_tunables'] = {
  "choose_local_tries"=>0,
  "choose_local_fallback_tries"=>0,
  "choose_total_tries"=>50,
  "chooseleaf_descend_once"=>1,
  "chooseleaf_vary_r"=>1,
  "straw_calc_version"=>1,
  "allowed_bucket_algs"=>54,
  "profile"=>"hammer",
  "optimal_tunables"=>0,
  "legacy_tunables"=>0,
  "require_feature_tunables"=>1,
  "require_feature_tunables2"=>1,
  "require_feature_tunables3"=>1,
  "has_v2_rules"=>0,
  "has_v3_rules"=>0,
  "has_v4_buckets"=>1
}

# sets the max open fds at the OS level
default['bcpc']['ceph']['max_open_files'] = 2048

# set tunables for ceph osd reovery
default['bcpc']['ceph']['paxos_propose_interval'] = 1
default['bcpc']['ceph']['osd_recovery_max_active'] = 1
default['bcpc']['ceph']['osd_recovery_threads'] = 1
default['bcpc']['ceph']['osd_recovery_op_priority'] = 1
default['bcpc']['ceph']['osd_max_backfills'] = 1
default['bcpc']['ceph']['osd_op_threads'] = 2
default['bcpc']['ceph']['osd_mon_report_interval_min'] = 5
default['bcpc']['ceph']['mon_osd_down_out_subtree_limit'] = "host"
