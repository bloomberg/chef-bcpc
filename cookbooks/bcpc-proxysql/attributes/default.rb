###########################################
#
#  General configuration for this cluster
#
###########################################
default['bcpc-proxysql']['admin']['config'] = {
  'proxysql_username' => make_config('proxysql-admin-user', 'admin'),
  'proxysql_password' => \
    make_config('proxysql-admin-password', secure_password),
  'proxysql_hostname' => '127.0.0.1',
  'proxysql_port' => 6032,
  'cluster_hostname' => node['bcpc']['management']['vip'],
  'cluster_port' => 3306,
  'monitor_username' => make_config('proxysql-monitor-user', 'monitor'),
  'monitor_password' => \
    make_config('proxysql-monitor-password', secure_password),
  'pxc_app_username' => make_config('proxysql-proxy-user', 'pxcapp'),
  'pxc_app_password' => make_config('proxysql-proxy-password', secure_password)
}
default['bcpc-proxysql']['admin_variables'] = {}
default['bcpc-proxysql']['mysql_servers'] = {
  'port' => 3306,
  'weight' => 1,
  'max_connections' => 3_000,
  'max_latency_ms' => 0
}
default['bcpc-proxysql']['mysql_variables'] = {
  'connect_timeout_server' => 5_000,
  'default_query_timeout' => 1_800_000,
  'long_query_time' => 10_000,
  'max_connections' => 5_000,
  'monitor_password' => \
    node['bcpc-proxysql']['admin']['config']['monitor_password'],
  'monitor_history' => 600_000,
  'monitor_connect_interval' => 60_000,
  'monitor_ping_interval' => 10_000,
  'monitor_read_only_interval' => 1_500,
  'monitor_read_only_timeout' => 1_000,
  'ping_interval_server' => 120_000,
  'ping_timeout_server' => 5_000,
  'threads' => 4
}
default['bcpc-proxysql']['hostgroups'] = {
  'writer' => 0,
  'reader' => 1
}
default['bcpc-proxysql']['mysql_query_rules'] = [
  {
    'rule_id' => 1,
    'match_pattern' => '^SELECT .* FOR UPDATE$',
    'destination_hostgroup' => node['bcpc-proxysql']['hostgroups']['writer'],
    'apply' => 1
  },
  {
    'rule_id' => 2,
    'match_pattern' => '^SELECT',
    'destination_hostgroup' => node['bcpc-proxysql']['hostgroups']['reader'],
    'apply' => 1
  }
]
default['bcpc-proxysql']['check']['interval'] = 1000
default['bcpc-proxysql']['check']['script'] = '/usr/bin/proxysql_galera_checker'
default['bcpc-proxysql']['check']['logfile'] = '/var/lib/proxysql/check.log'
default['bcpc-proxysql']['check']['writers'] = 1
default['bcpc-proxysql']['check']['writers_are_readers'] = 1
