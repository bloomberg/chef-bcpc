
#############################################
#
#  Hadoop specific configs
#
#############################################

default[:bcpc][:hadoop] = {}
default[:bcpc][:zookeeper][:id] = 0
default[:bcpc][:namenode][:id] = -1
default[:bcpc][:hadoop][:distribution][:version] = '-cdh5'
default[:bcpc][:hadoop][:distribution][:key] = 'cloudera-archive-5.key'
default[:bcpc][:repos][:cloudera] = 'http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh'
default[:bcpc][:hadoop][:disks] = []
default[:bcpc][:hadoop][:oozie][:admins] = []
default[:bcpc][:hadoop][:min_node_count] = 3
default[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated] = 3
