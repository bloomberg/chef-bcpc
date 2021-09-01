###############################################################################
# ProxySQL
###############################################################################

# Service status
default['bcpc']['proxysql']['enabled'] = false

# Repository
default['bcpc']['proxysql']['repo']['enabled'] = true
default['bcpc']['proxysql']['repo']['url'] =
 'https://repo.proxysql.com/ProxySQL/proxysql-2.2.x/bionic/ ./'
default['bcpc']['proxysql']['repo']['key'] = 'proxysql/release.key'
default['bcpc']['proxysql']['repo']['distribution'] = 'bionic'

# Connection information
default['bcpc']['proxysql']['host'] = 'primary.proxysql.service.consul'
default['bcpc']['proxysql']['port'] = 6033
default['bcpc']['proxysql']['admin_port'] = 6032

# General Variables
default['bcpc']['proxysql']['datadir'] = '/var/lib/proxysql'
default['bcpc']['proxysql']['restart_on_missing_heartbeats'] = 10
default['bcpc']['proxysql']['execute_on_exit_failure'] =
 "#{node['bcpc']['proxysql']['datadir']}/files/log-crash.sh"
default['bcpc']['proxysql']['errorlog'] = '/var/lib/proxysql/proxysql.log'

# The datadir specified in ProxySQL's default configuration file
default['bcpc']['proxysql']['default_datadir'] = '/var/lib/proxysql'

# Admin Variables
default['bcpc']['proxysql']['read_only'] = false
default['bcpc']['proxysql']['refresh_interval'] = 2000
default['bcpc']['proxysql']['restapi_enabled'] = true
default['bcpc']['proxysql']['restapi_port'] = 6070
default['bcpc']['proxysql']['prometheus_memory_metrics_interval'] = 120
default['bcpc']['proxysql']['web_enabled'] = true
default['bcpc']['proxysql']['web_port'] = 6071

# Admin Cluster Variables
default['bcpc']['proxysql']['cluster_check_interval_ms'] = 1000
default['bcpc']['proxysql']['cluster_diffs_before_sync'] = 3

# MySQL Variables
default['bcpc']['proxysql']['threads'] = 4
default['bcpc']['proxysql']['stacksize'] = 1048576
default['bcpc']['proxysql']['max_connections'] = 32768
default['bcpc']['proxysql']['have_ssl'] = false
default['bcpc']['proxysql']['use_tcp_keepalive'] = false
default['bcpc']['proxysql']['wait_timeout'] = 28800000
default['bcpc']['proxysql']['server_version'] = '5.7.26'
default['bcpc']['proxysql']['server_capabilities'] = 569899
default['bcpc']['proxysql']['enable_client_deprecate_eof'] = false
default['bcpc']['proxysql']['enable_server_deprecate_eof'] = false
default['bcpc']['proxysql']['multiplexing'] = true
default['bcpc']['proxysql']['free_connections_pct'] = 10
default['bcpc']['proxysql']['long_query_time'] = 10000
default['bcpc']['proxysql']['default_query_timeout'] = 86400000
default['bcpc']['proxysql']['max_transaction_time'] = 14400000
default['bcpc']['proxysql']['query_retries_on_failure'] = 1

# Galera Hostgroup Variables

# Whether or not ProxySQL should monitor the servers in the specified
# hostgroups and move them between hostgroups
default['bcpc']['proxysql']['galera']['active'] = 1

# The maximum number of 'writer' nodes
default['bcpc']['proxysql']['galera']['max_writers'] = 1

# Whether 'writer', 'backup writer', or neither should be reader nodes
default['bcpc']['proxysql']['galera']['writer_is_also_reader'] = 0

# The maximum number of write sets a node is allowed to fall behind before
# being shunned.
default['bcpc']['proxysql']['galera']['max_transactions_behind'] = 100

# Backend server configuration

# The weight of the MySQL backend running on the same physical server as
# ProxySQL. The higher the value, the more likely ProxySQL will choose it for
# incoming queries. In order to avoid additional network latency we want to
# choose the local backend.
default['bcpc']['proxysql']['mysql_servers']['local_weight'] = 1024

# The weight of MySQL backends running on remote servers. See above.
default['bcpc']['proxysql']['mysql_servers']['remote_weight'] = 1

# Whether to enable or disable compression on ProxySQL-MySQL connections
default['bcpc']['proxysql']['mysql_servers']['compression'] = 0

# The maximum number of connections ProxySQL will establish to each backend
default['bcpc']['proxysql']['mysql_servers']['max_connections'] = node['bcpc']['mysql']['max_connections']

# If greater than 0 and a backend's replication lag surpasses the given
# threshold it will be shunned until it catches up.
default['bcpc']['proxysql']['mysql_servers']['max_replication_lag'] = 0

# Whether or not to enable SSL on ProxySQL-MySQL connections
default['bcpc']['proxysql']['mysql_servers']['use_ssl'] = 0

# The maximum ping time of a backend before it is excluded from the connection
# pool
default['bcpc']['proxysql']['mysql_servers']['max_latency_ms'] = 0

# User Configuration

# The following configuration options are used for all users added to
# mysql_users.

# Whether or not the client is required to use SSL when connecting to ProxySQL
# as the given user
default['bcpc']['proxysql']['mysql_users']['use_ssl'] = 0

# If set, transactions started within a hostgroup will remain within that
# hostgroup regardless of any other rules
default['bcpc']['proxysql']['mysql_users']['transaction_persistent'] = 0

# If set queries bypass the query processing layer and are sent directly to the
# backend server
default['bcpc']['proxysql']['mysql_users']['fast_forward'] = 1

# The maximum number of allowable frontend connections for a specific user
default['bcpc']['proxysql']['mysql_users']['max_connections'] = 32768

# Query Rules

# An array of rules, each containing a key=value pair, defining the query rules
# ProxySQL will be configured with.
default['bcpc']['proxysql']['query_rules'] = nil

# Scheduler

# Whether or not the query digest check is active (0 = false, 1 = true)
default['bcpc']['proxysql']['scheduler']['query_digest_check']['active'] = 1
# How often the query digest check should be run (milliseconds)
default['bcpc']['proxysql']['scheduler']['query_digest_check']['interval'] = 3600000
# The percentage of server memory allowed to be used by the query digest table
# before it is reset
default['bcpc']['proxysql']['scheduler']['query_digest_check']['threshold'] = 10
