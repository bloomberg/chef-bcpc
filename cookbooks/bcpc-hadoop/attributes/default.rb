#############################################
#
#  Hadoop specific configs
#
#############################################

default["bcpc"]["hadoop"] = {}
default["bcpc"]["zookeeper"]["id"] = 0
default["bcpc"]["namenode"]["id"] = -1
default["bcpc"]["hadoop"]["distribution"]["version"] = 'HDP'
default["bcpc"]["hadoop"]["distribution"]["key"] = 'hortonworks.key'
default["bcpc"]["repos"]["hortonworks"] = 'http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.0.11.0'
default["bcpc"]["repos"]["hdp_utils"] = 'http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.16/repos/ubuntu12'
default["bcpc"]["hadoop"]["disks"] = []
default["bcpc"]["hadoop"]["oozie"]["admins"] = []
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_memory"]["ratio"] = 0.8
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_memory"]["size"] = nil
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_vcpu"]["ratio"] = 0.8
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_vcpu"]["count"] = nil
default["bcpc"]["hadoop"]["yarn"]["scheduler"] = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler"
default["bcpc"]["hadoop"]["hdfs"]["HA"] = false
default["bcpc"]["hadoop"]["hdfs"]["failed_volumes_tolerated"] = 1
default["bcpc"]["hadoop"]["hdfs"]["dfs_replication_factor"] = 3
default["bcpc"]["hadoop"]["jmx_enabled"] = true
default["bcpc"]["hadoop"]["namenode"]["jmx"]["port"] = 10111
default["bcpc"]["hadoop"]["namenode"]["rpc"]["port"] = 8020
default["bcpc"]["hadoop"]["namenode"]["http"]["port"] = 50070 
default["bcpc"]["hadoop"]["namenode"]["https"]["port"] = 50080 
default["bcpc"]["hadoop"]["datanode"]["jmx"]["port"] = 10112
default["bcpc"]["hadoop"]["hbase_master"]["jmx"]["port"] = 10101
default["bcpc"]["hadoop"]["hbase_rs"]["jmx"]["port"] = 10102
default["bcpc"]["hadoop"]["kafka"]["jmx"]["port"] = 9995
default["bcpc"]["hadoop"]["java"] = "/usr/lib/jvm/java-1.7.0-openjdk-amd64"
#
# Attributes for service rolling restart process
#
# Number of tries to acquire the lock required to restart the process
default["bcpc"]["hadoop"]["restart_lock_acquire"]["max_tries"] = 5
# The path in ZK where the restart locks (znodes)  need to be created
# The path should exist in ZooKeeper e.g. "/lock" and the default is "/"
default["bcpc"]["hadoop"]["restart_lock"]["root"] = "/"
# Sleep time in seconds between tries to acquire the lock for restart
default["bcpc"]["hadoop"]["restart_lock_acquire"]["sleep_time"] = 2
# Flag to set whether the HDFS datanode restart process was successful or not
default["bcpc"]["hadoop"]["datanode"]["restart_failed"] = false
# Attribute to save the time when HDFS datanode restart process failed
default["bcpc"]["hadoop"]["datanode"]["restart_failed_time"] = ""
# Flag to control whether automatic restarts due to config changes need to be skipped 
# for e.g. if ZK quorum is down or if the recipes need to be run in a non ZK env
default["bcpc"]["hadoop"]["skip_restart_coordination"] = false

default[:bcpc][:hadoop][:nn_hosts] = []
default[:bcpc][:hadoop][:jn_hosts] = []
default[:bcpc][:hadoop][:rm_hosts] = []
default[:bcpc][:hadoop][:hs_hosts] = []
default[:bcpc][:hadoop][:dn_hosts] = []
default[:bcpc][:hadoop][:hb_hosts] = []
default[:bcpc][:hadoop][:hive_hosts] = []
default[:bcpc][:hadoop][:oozie_hosts] = []
default[:bcpc][:hadoop][:httpfs_hosts] = []
default[:bcpc][:hadoop][:httpfs_hosts] = []
default[:bcpc][:hadoop][:rs_hosts] = []
default[:bcpc][:hadoop][:mysql_hosts] = []

default["bcpc"]["keepalived"]["config_template"] = "keepalived.conf_hadoop"

default["bcpc"]["revelytix"]["loom_username"] = "loom"
default["bcpc"]["revelytix"]["activescan_hdfs_user"] = "activescan-user"
default["bcpc"]["revelytix"]["activescan_hdfs_enabled"] = "true"
default["bcpc"]["revelytix"]["activescan_table_enabled"] = "true"
default["bcpc"]["revelytix"]["hdfs_scan_interval"] = 60
default["bcpc"]["revelytix"]["hdfs_parse_lines"] = 50
default["bcpc"]["revelytix"]["hdfs_score_threshold"] = 0.25
default["bcpc"]["revelytix"]["hdfs_max_buffer_size"] = 8388608
default["bcpc"]["revelytix"]["persist_mode"] = "hive"
default["bcpc"]["revelytix"]["dataset_persist_dir"] = "loom-datasets"
default["bcpc"]["revelytix"]["temporary_file_dir"] = "hdfs-default:loom-temp"
default["bcpc"]["revelytix"]["job_service_thread_pool_size"] = 10
default["bcpc"]["revelytix"]["security_authentication"] = "loom"
default["bcpc"]["revelytix"]["security_enabled"] = "true"
default["bcpc"]["revelytix"]["ssl_enabled"] = "true"
default["bcpc"]["revelytix"]["ssl_port"] = 8443
default["bcpc"]["revelytix"]["ssl_keystore"] = "config/keystore"
default["bcpc"]["revelytix"]["ssl_key_password"] = ""
default["bcpc"]["revelytix"]["ssl_trust_store"] = "config/truststore"
default["bcpc"]["revelytix"]["ssl_trust_password"] = ""
default["bcpc"]["revelytix"]["loom_dist_cache"] = "loom-dist-cache"
default["bcpc"]["revelytix"]["hive_classloader_blacklist_jars"] = "slf4j,log4j,commons-logging"
default["bcpc"]["revelytix"]["port"] = 8080
default["bcpc"]["hadoop"]["zabbix"]["history_days"] = 1
default["bcpc"]["hadoop"]["zabbix"]["trend_days"] = 15
default["bcpc"]["hadoop"]["zabbix"]["cron_check_time"] = 240
default["bcpc"]["hadoop"]["graphite"]["queries"] = {
   'namenode' => [
    {
      'type'  => "jmx",
      'query' => "memory.HeapMemoryUsage_committed",
      'key'   => "nnheapmem",
      'trigger_val' => "max(61,0)",
      'trigger_cond' => "=0",
      'trigger_name' => "NameNodeAvailability",
      'trigger_enable' => true
    },
    {
      'type'  => "jmx",
      'query' => "nn_fs_name_system_state.FSNamesystemState.NumStaleDataNodes",
      'key'   => "numstaledn"
    }
  ],
  'hbase_master' => [
    {
      'type'  => "jmx",
      'query' => "memory.NonHeapMemoryUsage_committed",
      'key'   => "hbasenonheapmem",
      'trigger_val' => "max(61,0)",
      'trigger_cond' => "=0",
      'trigger_name' => "HBaseMasterAvailability",
      'trigger_dep' => ["NameNodeAvailability"]
    },
    {
      'type'  => "jmx",
      'query' => "memory.HeapMemoryUsage_committed",
      'key'   => "hbaseheapmem",
      'history_days' => 2,
      'trend_days' => 30
    },
    {
      'type'  => "jmx",
      'query' => "hbm_server.Master.numRegionServers",
      'key'   => "numrsservers",
      'trigger_val' => "max(61,0)",
      'trigger_cond' => "=0",
      'trigger_name' => "HBaseRSAvailability",
      'trigger_enable' => true,
      'trigger_dep' => ["HBaseMasterAvailability"]
    }
  ]
}
