###############################################################################
# ceph
###############################################################################

ceph_deploy_package = 'ceph-deploy_2.0.1-0ubuntu1_all.deb'
default['bcpc']['ceph']['ceph-deploy']['file'] = ceph_deploy_package
default['bcpc']['ceph']['ceph-deploy']['source'] = "#{default['bcpc']['web_server']['url']}/#{ceph_deploy_package}"
default['bcpc']['ceph']['ceph-deploy']['checksum'] = '6ecd4769dbe3d65ff114f458f60840b976cb73873f7e825987613f929ffed911'

default['bcpc']['ceph']['repo']['enabled'] = false
default['bcpc']['ceph']['repo']['url'] = ''

default['bcpc']['ceph']['pg_num'] = 32
default['bcpc']['ceph']['pgp_num'] = 32
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

# When raising pg(p)_num and size on large deployments, one may also need
# to raise mon_max_pg_per_osd to allow OSDs to recover under certain
# conditions.
default['bcpc']['ceph']['mon_max_pg_per_osd'] = 450

# The maximum value of pg_num and pgp_num for any given pool.
default['bcpc']['ceph']['mon_max_pool_pg_num'] = 131072

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

# Set tunables for Ceph OSD recovery
default['bcpc']['ceph']['paxos_propose_interval'] = 1
default['bcpc']['ceph']['osd_recovery_max_active'] = 1
default['bcpc']['ceph']['osd_recovery_op_priority'] = 1
default['bcpc']['ceph']['osd_max_backfills'] = 1
default['bcpc']['ceph']['osd_mon_report_interval'] = 5

default['bcpc']['ceph']['osd_max_scrubs'] = 1
default['bcpc']['ceph']['osd_deep_scrub_interval'] = 2592000
default['bcpc']['ceph']['osd_scrub_max_interval'] = 604800
default['bcpc']['ceph']['osd_scrub_sleep'] = 0.05
default['bcpc']['ceph']['osd_memory_target'] = 8589934592
default['bcpc']['ceph']['mon_osd_down_out_interval'] = 300

# BlueStore tuning
default['bcpc']['ceph']['bluestore_rocksdb_options'] = nil

# Set RBD default feature set to only include layering and
# deep-flatten. Other values (in particular, exclusive-lock) may prevent
# instances from being able to access their root file system after a crash.
default['bcpc']['ceph']['rbd_default_features'] = 33

# Disable automated autoscaler changes on new pools by default, but still
# raise a health warning when PGs are deemed undersized.
default['bcpc']['ceph']['osd_pool_default_pg_autoscale_mode'] = 'warn'

# ceph mgr,mon,osd service installation flags
default['bcpc']['ceph']['mgr']['enabled'] = true
default['bcpc']['ceph']['mon']['enabled'] = true
default['bcpc']['ceph']['osd']['enabled'] = true

# ceph mgr module configuration

# https://tracker.ceph.com/issues/50778
# Mons may become unstable when the progress module is enabled.
default['bcpc']['ceph']['module']['progress']['enabled'] = false
