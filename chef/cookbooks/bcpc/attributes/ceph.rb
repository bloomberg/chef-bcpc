###############################################################################
# ceph
###############################################################################

default['bcpc']['ceph']['repo']['enabled'] = false
default['bcpc']['ceph']['repo']['url'] = ''

default['bcpc']['ceph']['pg_num'] = 8
default['bcpc']['ceph']['pgp_num'] = 8
default['bcpc']['ceph']['osds'] = %w(sdb sdc sdd sde)
default['bcpc']['ceph']['choose_leaf_type'] = 0
default['bcpc']['ceph']['osd_scrub_load_threshold'] = 0.5

# new osds will be weighted to 0 by default
default['bcpc']['ceph']['osd_crush_initial_weight'] = 0

# Help minimize scrub influence on cluster performance
default['bcpc']['ceph']['osd_scrub_begin_hour'] = 21
default['bcpc']['ceph']['osd_scrub_end_hour'] = 10
default['bcpc']['ceph']['osd_scrub_sleep'] = 0.1
default['bcpc']['ceph']['osd_scrub_chunk_min'] = 1
default['bcpc']['ceph']['osd_scrub_chunk_max'] = 5

# Set to 0 to disable. See http://tracker.ceph.com/issues/8103
default['bcpc']['ceph']['pg_warn_max_obj_skew'] = 10

# Set the default niceness of Ceph OSD and monitor processes
default['bcpc']['ceph']['osd_niceness'] = -10
default['bcpc']['ceph']['mon_niceness'] = -10

# Set tcmalloc max total thread cache
default['bcpc']['ceph']['tcmalloc_max_total_thread_cache_bytes'] = '128MB'

# Set the max open fds at the OS level
default['bcpc']['ceph']['max_open_files'] = 2048

# Set tunables for ceph osd reovery
default['bcpc']['ceph']['paxos_propose_interval'] = 1
default['bcpc']['ceph']['osd_recovery_max_active'] = 1
default['bcpc']['ceph']['osd_recovery_threads'] = 2
default['bcpc']['ceph']['osd_recovery_op_priority'] = 1
default['bcpc']['ceph']['osd_max_backfills'] = 3
default['bcpc']['ceph']['osd_op_threads'] = 2
default['bcpc']['ceph']['osd_mon_report_interval_min'] = 5
default['bcpc']['ceph']['osd_max_scrubs'] = 5
default['bcpc']['ceph']['osd_deep_scrub_interval'] = 2592000
default['bcpc']['ceph']['osd_scrub_max_interval'] = 604800
default['bcpc']['ceph']['osd_scrub_sleep'] = 0.05
default['bcpc']['ceph']['osd_memory_target'] = 9663676416

# BlueStore tuning
default['bcpc']['ceph']['bluestore_rocksdb_options'] = [
  'compression=kNoCompression',
  'max_write_buffer_number=4',
  'min_write_buffer_number_to_merge=1',
  'recycle_log_file_num=4',
  'write_buffer_size=268435456',
  'writable_file_max_buffer_size=0',
  'compaction_readahead_size=2097152',
  'max_background_compactions=4',
]

default['bcpc']['ceph']['bluestore_cache_size_ssd'] = 10737418240

# Set RBD default feature set to only include layering and
# deep-flatten. Other values (in particular, exclusive-lock) may prevent
# instances from being able to access their root file system after a crash.
default['bcpc']['ceph']['rbd_default_features'] = 33
