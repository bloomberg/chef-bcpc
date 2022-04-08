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

# https://docs.ceph.com/en/latest/security/CVE-2021-20288/
# By default, new clusters should reclaim global_id for good security posture
default['bcpc']['ceph']['mon_auth_allow_insecure_global_id_reclaim'] = false

# The number of threads which the mon can scale to for intensive
# operations (such as compaction).  Larger clusters may benefit from
# more threads if they are available.
default['bcpc']['ceph']['mon_cpu_threads'] = 16

# Max time between consecutive beacons before marking a mgr as failed.
# And how long between mgr beacons to the mons.
# The defaults are too small for large clusters with lots of PGs; it is
# necessary to increase both the timeout and period of action.
#
# Also see mgr_stats_threshold if stats are observed to be continually
# missed, but note that it can work against increases in beacon and
# stats/tick period increases by leaving the mgr tied up compiling stats.
default['bcpc']['ceph']['mon_mgr_beacon_grace'] = 60
default['bcpc']['ceph']['mgr_stats_period'] = 10
default['bcpc']['ceph']['mgr_stats_threshold'] = 5
default['bcpc']['ceph']['mgr_tick_period'] = 10

# In a similar vein to the above, when the active mgr changes, the
# default listener backlog size can hit capacity on large clusters.
# Increase it to avoid clients from getting refused connections when
# the mgr turns.
#
# Note: this tunable must be <= `net.core.somaxconn`.
default['bcpc']['ceph']['mgr_ms_tcp_listen_backlog'] = 1024

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

# Set tunables for Ceph OSD recovery
default['bcpc']['ceph']['paxos_propose_interval'] = 1
default['bcpc']['ceph']['osd_recovery_max_active'] = 1
default['bcpc']['ceph']['osd_recovery_threads'] = 2
default['bcpc']['ceph']['osd_recovery_op_priority'] = 1
default['bcpc']['ceph']['osd_max_backfills'] = 1
default['bcpc']['ceph']['osd_op_threads'] = 2
default['bcpc']['ceph']['osd_mon_report_interval_min'] = 5
default['bcpc']['ceph']['osd_max_scrubs'] = 5
default['bcpc']['ceph']['osd_deep_scrub_interval'] = 2592000
default['bcpc']['ceph']['osd_scrub_max_interval'] = 604800
default['bcpc']['ceph']['osd_scrub_sleep'] = 0.05
default['bcpc']['ceph']['osd_memory_target'] = 7516192768
default['bcpc']['ceph']['mon_osd_down_out_interval'] = 300

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

# https://tracker.ceph.com/issues/50017
# Some issues noted with multiple fsck/quick fix threads; we'll wait
# around a bit longer if it improves odds that fsck doesn't shred OSDs.
default['bcpc']['ceph']['bluestore_fsck_quick_fix_threads'] = 1

# Set RBD default feature set to only include layering and
# deep-flatten. Other values (in particular, exclusive-lock) may prevent
# instances from being able to access their root file system after a crash.
default['bcpc']['ceph']['rbd_default_features'] = 33

# ceph mgr,mon,osd service installation flags
default['bcpc']['ceph']['mgr']['enabled'] = true
default['bcpc']['ceph']['mon']['enabled'] = true
default['bcpc']['ceph']['osd']['enabled'] = true

# ceph mgr module configuration

# https://tracker.ceph.com/issues/50778
# Mons may become unstable when the progress module is enabled.
default['bcpc']['ceph']['module']['progress']['enabled'] = false
