#
# Name of jmxtrans software downloaded
#
default['jmxtrans']['sw']="jmxtrans-20120525-210643-4e956b1144.zip"
#
# Add additional JMX queries following the existing queries as sample
# Also refer to the jmxtrans community cookbook if queries of the category you are planning to add is
# already existing in the defualt attributes file
#
default['jmxtrans']['default_queries']['kafka'] = [
  {
     'obj' => "\\\"kafka.server\\\":type=\\\"BrokerTopicMetrics\\\",name=*",
     'result_alias' => "kafka.BrokerTopicMetrics",
     'attr' => [ "Count", 
                 "MeanRate", 
                 "OneMinuteRate", 
                 "FiveMinuteRate", 
                 "FifteenMinuteRate" 
               ]
  },
  {
     'obj' => "\\\"kafka.server\\\":type=\\\"DelayedFetchRequestMetrics\\\",name=*",
     'result_alias' => "kafka.server.DelayedFetchRequestMetrics",
     'attr' => [ "Count", 
                 "MeanRate", 
                 "OneMinuteRate", 
                 "FiveMinuteRate", 
                 "FifteenMinuteRate"
               ]
  }
]
default['jmxtrans']['default_queries']['datanode'] = [
  {
     'obj' => "Hadoop:name=JvmMetrics,service=DataNode",
     'result_alias' => "dn_jvm_metrics",
     'attr' => [
                      "GcCount",
                      "GcTimeMillis",
                      "LogError",
                      "LogFatal",
                      "LogInfo",
                      "LogWarn",
                      "MemHeapCommittedM",
                      "MemHeapUsedM",
                      "MemMaxM",
                      "MemNonHeapCommittedM",
                      "MemNonHeapUsedM",
                      "ThreadsBlocked",
                      "ThreadsNew",
                      "ThreadsRunnable",
                      "ThreadsTerminated",
                      "ThreadsTimedWaiting",
                      "ThreadsWaiting"
               ]
  },
  {
     'obj' => "Hadoop:name=DataNodeInfo,service=DataNode",
     'result_alias' => "dn_data_node_info",
     'attr' => [
                      "ClusterId",
                      "HttpPort",
                      "NamenodeAddresses",
                      "RpcPort",
                      "Version",
                      "VolumeInfo",
                      "XceiverCount"
               ]
  }
]
default['jmxtrans']['default_queries']['namenode'] = [
  {
     'obj' => "Hadoop:name=JvmMetrics,service=NameNode",
     'result_alias' => "nn_jvm_metrics",
     'attr' => [
                      "GcCount",
                      "GcCountCopy",
                      "GcCountMarkSweepCompact",
                      "GcTimeMillis",
                      "GcTimeMillisCopy",
                      "GcTimeMillisMarkSweepCompact",
                      "LogError",
                      "LogFatal",
                      "LogInfo",
                      "LogWarn",
                      "MemHeapCommittedM",
                      "MemHeapUsedM",
                      "MemMaxM",
                      "MemNonHeapCommittedM",
                      "MemNonHeapUsedM",
                      "ThreadsBlocked",
                      "ThreadsNew",
                      "ThreadsRunnable",
                      "ThreadsTerminated",
                      "ThreadsTimedWaiting",
                      "ThreadsWaiting"
              ]
  },
  {
     'obj' => "Hadoop:name=FSNamesystem,service=NameNode",
     'result_alias' => "nn_fs_name_system",
     'attr' => [
                      "BlockCapacity",
                      "BlocksTotal",
                      "CapacityRemaining",
                      "CapacityRemainingGB",
                      "CapacityTotal",
                      "CapacityTotalGB",
                      "CapacityUsed",
                      "CapacityUsedGB",
                      "CapacityUsedNonDFS",
                      "CorruptBlocks",
                      "ExcessBlocks",
                      "ExpiredHeartbeats",
                      "FilesTotal",
                      "LastCheckpointTime",
                      "LastWrittenTransactionId",
                      "MillisSinceLastLoadedEdits",
                      "MissingBlocks",
                      "PendingDataNodeMessageCount",
                      "PendingDeletionBlocks",
                      "PendingReplicationBlocks",
                      "PostponedMisreplicatedBlocks",
                      "ScheduledReplicationBlocks",
                      "Snapshots",
                      "SnapshottableDirectories",
                      "StaleDataNodes",
                      "TotalFiles",
                      "TotalLoad",
                      "TransactionsSinceLastCheckpoint",
                      "TransactionsSinceLastLogRoll",
                      "UnderReplicatedBlocks",
                      "tag.HAState"
             ]
  },
  {
     'obj' => "Hadoop:name=FSNamesystemState,service=NameNode",
     'result_alias' => "nn_fs_name_system_state",
     'attr' => [
                      "BlocksTotal",
                      "CapacityRemaining",
                      "CapacityTotal",
                      "CapacityUsed",
                      "FSState",
                      "FilesTotal",
                      "NumDeadDataNodes",
                      "NumLiveDataNodes",
                      "NumStaleDataNodes",
                      "PendingReplicationBlocks",
                      "ScheduledReplicationBlocks",
                      "TotalLoad",
                      "UnderReplicatedBlocks"
               ]
  },
  {
    'obj' => "Hadoop:name=NameNodeActivity,service=NameNode",
    'result_alias' => "nn_name_node_activity",
    'attr' => [
                      "AddBlockOps",
                      "AllowSnapshotOps",
                      "BlockReportAvgTime",
                      "BlockReportNumOps",
                      "CreateFileOps",
                      "CreateSnapshotOps",
                      "CreateSymlinkOps",
                      "DeleteFileOps",
                      "DeleteSnapshotOps",
                      "DisallowSnapshotOps",
                      "FileInfoOps",
                      "FilesAppended",
                      "FilesCreated",
                      "FilesDeleted",
                      "FilesInGetListingOps",
                      "FilesRenamed",
                      "FsImageLoadTime",
                      "GetAdditionalDatanodeOps",
                      "GetBlockLocations",
                      "GetLinkTargetOps",
                      "GetListingOps",
                      "ListSnapshottableDirOps",
                      "RenameSnapshotOps",
                      "SafeModeTime",
                      "SnapshotDiffReportOps",
                      "SyncsAvgTime",
                      "SyncsNumOps",
                      "TransactionsAvgTime",
                      "TransactionsBatchedInSync",
                      "TransactionsNumOps",
                      "tag.Context",
                      "tag.Hostname",
                      "tag.ProcessName",
                      "tag.SessionId"
              ]
  },
  {
    'obj' => "Hadoop:name=NameNodeInfo,service=NameNode",
    'result_alias' => "nn_name_node_info",
    'attr' => [
                      "BlockPoolId",
                      "BlockPoolUsedSpace",
                      "ClusterId",
                      "DeadNodes",
                      "DecomNodes",
                      "DistinctVersionCount",
                      "DistinctVersions",
                      "Free",
                      "JournalTransactionInfo",
                      "LiveNodes",
                      "NameDirStatuses",
                      "NonDfsUsedSpace",
                      "NumberOfMissingBlocks",
                      "PercentBlockPoolUsed",
                      "PercentRemaining",
                      "PercentUsed",
                      "Safemode",
                      "SoftwareVersion",
                      "Threads",
                      "Total",
                      "TotalBlocks",
                      "TotalFiles",
                      "UpgradeFinalized",
                      "Used",
                      "Version"
             ]
  }
]
default['jmxtrans']['default_queries']['hbase_master'] = [
  {
    'obj' => "Hadoop:name=JvmMetrics,service=HBase",
    'result_alias' => "hbm_jvm_metrics",
    'attr' => [
                      "GcCount",
                      "GcTimeMillis",
                      "LogError",
                      "LogFatal",
                      "LogInfo",
                      "LogWarn",
                      "MemHeapCommittedM",
                      "MemHeapUsedM",
                      "MemMaxM",
                      "MemNonHeapCommittedM",
                      "MemNonHeapUsedM",
                      "ThreadsBlocked",
                      "ThreadsNew",
                      "ThreadsRunnable",
                      "ThreadsTerminated",
                      "ThreadsTimedWaiting",
                      "ThreadsWaiting"
              ]
  },
  {
    'obj' => "Hadoop:name=Master,service=HBase,sub=Server",
    'result_alias' => "hbm_server",
    'attr' => [
                      "averageLoad",
                      "clusterRequests",
                      "masterActiveTime",
                      "masterStartTime",
                      "numDeadRegionServers",
                      "numRegionServers"
              ]
  }
]
default['jmxtrans']['default_queries']['hbase_rs'] = [
  {
    'obj' => "Hadoop:name=JvmMetrics,service=HBase",
    'result_alias' => "hb_rs_jvm_metrics",
    'attr' => [
                      "GcCount",
                      "GcTimeMillis",
                      "LogError",
                      "LogFatal",
                      "LogInfo",
                      "LogWarn",
                      "MemHeapCommittedM",
                      "MemHeapUsedM",
                      "MemMaxM",
                      "MemNonHeapCommittedM",
                      "MemNonHeapUsedM",
                      "ThreadsBlocked",
                      "ThreadsNew",
                      "ThreadsRunnable",
                      "ThreadsTerminated",
                      "ThreadsTimedWaiting",
                      "ThreadsWaiting"
              ]
  },
  {
    'obj' => "Hadoop:name=RegionServer,service=HBase,sub=Server",
    'result_alias' => "hb_rs_server",
    'attr' => [
                      "regionCount",
                      "storeCount",
                      "totalRequestCount",
                      "readRequestCount",
                      "writeRequestCount",
                      "slowGetCount",
                      "slowAppendCount",
                      "slowPutCount",
                      "blockCacheHitCount",
                      "blockCacheMissCount",
                      "blockCacheCount",
                      "blockCacheEvictionCount",
                      "blockCacheSize",
                      "blockCountHitPercent"
              ]
  }
]
