package "xfsprogs" do
  action :install
end

directory "/disk" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

if node[:bcpc][:hadoop][:disks].length > 0 then
  node[:bcpc][:hadoop][:disks].each_index do |i|
    directory "/disk/#{i}" do
      owner "root"
      group "root"
      mode 00755
      action :create
      recursive true
    end
   
    d = node[:bcpc][:hadoop][:disks][i]
    execute "mkfs -t xfs -f /dev/#{d}" do
      not_if "file -s /dev/#{d} | grep -q 'SGI XFS filesystem'"
    end
 
    mount "/disk/#{i}" do
      device "/dev/#{d}"
      fstype "xfs"
      options "noatime,nodiratime,inode64"
      action [:enable, :mount]
    end
  end
  node.set[:bcpc][:hadoop][:mounts] = (0..node[:bcpc][:hadoop][:disks].length-1).to_a
else
  Chef::Log.fatal!('Please specify some node[:bcpc][:hadoop][:disks]!')
end


case node["platform_family"]
when "debian"
  apt_repository "cloudera" do
    uri node['bcpc']['repos']['cloudera']
    distribution node['lsb']['codename'] + node[:bcpc][:hadoop][:distribution][:version]
    components ["contrib"]
    arch "amd64"
    key node[:bcpc][:hadoop][:distribution][:key]
  end
  apt_repository "cloudera-lzo" do
    uri node['bcpc']['repos']['cloudera-lzo']
    distribution "lucid-gplextras4"
    components ["contrib"]
    key "cloudera-archive-4.key"
  end

  %w{hadoop
     hbase
     hive
     oozie
     pig
     zookeeper
     impala
     webhcat
     hadoop-httpfs
     hive-hcatalog
     hue}.each do |w|
    directory "/etc/#{w}/conf.#{node.chef_environment}" do
      owner "root"
      group "root"
      mode 00755
      action :create
      recursive true
    end

    bash "update-#{w}-conf-alternatives" do
      code %Q{
       update-alternatives --install /etc/#{w}/conf #{w}-conf /etc/#{w}/conf.#{node.chef_environment} 50
       update-alternatives --set #{w}-conf /etc/#{w}/conf.#{node.chef_environment}
      }
    end
  end

when "rhel"
  ""
  # do things on RHEL platforms (redhat, centos, scientific, etc)
end

ruby_block "initialize-hadoop-configs" do
    block do
      make_config('mysql-hive-password', secure_password)
      make_config('oozie-keystore-password', secure_password)
      make_config('mysql-hue-password', secure_password)
      make_config('hue-session-key', secure_password)
      make_config('mysql-oozie-password', secure_password)
    end
end

#
#set up hadoop conf
#
hadoop_conf_files = %w{capacity-scheduler.xml
   container-executor.cfg
   core-site.xml
   hadoop-metrics2.properties
   hadoop-metrics.properties
   hadoop-policy.xml
   hdfs-site.xml
   log4j.properties
   mapred-site.xml
   slaves
   ssl-client.xml
   ssl-server.xml
   yarn-site.xml
  }
node[:bcpc][:hadoop][:hdfs][:HA] == true and hadoop_conf_files.insert(-1,"hdfs-site_HA.xml")

hadoop_conf_files.each do |t|
   template "/etc/hadoop/conf/#{t}" do
     source "hdp_#{t}.erb"
     mode 0644
     variables(:nn_hosts => get_nodes_for("namenode*") ,
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :jn_hosts => get_nodes_for("journalnode"),
               :rm_host  => get_nodes_for("resource_manager"),
               :dn_hosts => get_nodes_for("datanode"),
               :mounts => node[:bcpc][:hadoop][:mounts])
   end
end

%w{yarn-env.sh
  hadoop-env.sh}.each do |t|
 template "/etc/hadoop/conf/#{t}" do
   source "hdp_#{t}.erb"
   mode 0644
   variables(:nn_hosts => get_nodes_for("namenode"),
             :zk_hosts => get_nodes_for("zookeeper_server"),
             :jn_hosts => get_nodes_for("journalnode"),
             :mounts => node[:bcpc][:hadoop][:mounts])
 end
end

#
# Set up zookeeper configs
#
%w{zoo.cfg
  log4j.properties
  configuration.xsl
 }.each do |t|
 template "/etc/zookeeper/conf/#{t}" do
   source "zk_#{t}.erb"
   mode 0644
   variables(:nn_hosts => get_nodes_for("namenode"),
             :zk_hosts => get_nodes_for("zookeeper_server"),
             :jn_hosts => get_nodes_for("journalnode"),
             :mounts => node[:bcpc][:hadoop][:mounts])
 end
end

#
# Set up hbase configs
#
%w{hadoop-metrics.properties
   hbase-env.sh
   hbase-policy.xml
   hbase-site.xml
   log4j.properties
   regionservers}.each do |t|
   template "/etc/hbase/conf/#{t}" do
     source "hb_#{t}.erb"
     mode 0644
     variables(:nn_hosts => get_nodes_for("namenode"),
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :jn_hosts => get_nodes_for("journalnode"),
               :rs_hosts => get_nodes_for("region_server"),
               :mounts => node[:bcpc][:hadoop][:mounts])
  end
end

#
# Set up hive configs
#
%w{hive-exec-log4j.properties
   hive-log4j.properties
   hive-site.xml }.each do |t|
   template "/etc/hive/conf/#{t}" do
     source "hv_#{t}.erb"
     mode 0644
     variables(:mysql_hosts => get_mysql_nodes.map{ |m| m.hostname },
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :hive_host => get_nodes_for("hive_metastore"))
  end
end

#
# Set up oozie configs
#
%w{
  oozie-env.sh
  oozie-site.xml
  adminusers.txt
  oozie-default.xml
  oozie-log4j.properties
  }.each do |t|
  template "/etc/oozie/conf/#{t}" do
    source "ooz_#{t}.erb"
    mode 0644
    variables(:mysql_hosts => get_mysql_nodes.map{ |m| m.hostname },
              :zk_hosts => get_nodes_for("zookeeper_server"),
              :hive_host => get_nodes_for("hive_metastore"))
  end
end
link "/etc/oozie/conf.#{node.chef_environment}/hive-site.xml" do
  to "/etc/hive/conf.#{node.chef_environment}/hive-site.xml"
end
link "/etc/oozie/conf.#{node.chef_environment}/core-site.xml" do
  to "/etc/hadoop/conf.#{node.chef_environment}/core-site.xml"
end
link "/etc/oozie/conf.#{node.chef_environment}/yarn-site.xml" do
  to "/etc/hadoop/conf.#{node.chef_environment}/yarn-site.xml"
end

#
# Set up impala configs
#

link "/etc/impala/conf.#{node.chef_environment}/hive-site.xml" do
  to "/etc/hive/conf.#{node.chef_environment}/hive-site.xml"
end
link "/etc/impala/conf.#{node.chef_environment}/core-site.xml" do
  to "/etc/hadoop/conf.#{node.chef_environment}/core-site.xml"
end
link "/etc/impala/conf.#{node.chef_environment}/hdfs-site.xml" do
  to "/etc/hadoop/conf.#{node.chef_environment}/hdfs-site.xml"
end
link "/etc/impala/conf.#{node.chef_environment}/hbase-site.xml" do
  to "/etc/hbase/conf.#{node.chef_environment}/hbase-site.xml"
end

#
# HTTPFS and Hue configs
#
%w{
  httpfs-env.sh
  httpfs-log4j.properties
  httpfs-signature.secret
  httpfs-site.xml
   }.each do |t|
   template "/etc/hadoop-httpfs/conf/#{t}" do
     source "#{t}.erb"
     mode 0644
  end
end

link "/etc/hive-hcatalog/conf.#{node.chef_environment}/hive-site.xml" do
  to "/etc/hive/conf.#{node.chef_environment}/hive-site.xml"
end

#
# HUE Configs
#
%w{
  hue.ini
  log4j.properties
  log.conf}.each do |t|
   template "/etc/hue/conf/#{t}" do
     source "hue_#{t}.erb"
     mode 0644
     variables(:impala_hosts => get_nodes_for("datanode") ,
               :zk_hosts => get_nodes_for("zookeeper_server"),
               :rm_host  => get_nodes_for("resource_manager"),
               :hive_host  => get_nodes_for("hive"),
               :oozie_host  => get_nodes_for("oozie"),
               :httpfs_host => get_nodes_for("httpfs"),
               :hb_host  => get_nodes_for("master"))
  end
end

package "openjdk-7-jdk" do
  action :upgrade
end

package "zookeeper" do
  action :upgrade
end
