
%w{hadoop-yarn-nodemanager
   hadoop-hdfs-datanode
   hadoop-mapreduce
   hbase-regionserver
   hadoop-client
   hadoop-lzo
   impala-server
   impala
   hive
   impala-shell}.each do |pkg|
  package pkg do
    action :upgrade
  end
end


node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs/dn" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
    recursive true
  end
end

if node[:bcpc][:hadoop][:mounts].length <= node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]
  Chef::Log.fatal!('You have fewer node[:bcpc][:hadoop][:disks] than node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]! See comments of HDFS-4442.')
end

%w{libmysql-java}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

link "/usr/lib/hive/lib/mysql.jar" do
  to "/usr/share/java/mysql.jar"
end

%w{hadoop-yarn-nodemanager hadoop-hdfs-datanode}.each do |svc|
  service svc do
    action :enable
    subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
    subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
  end
end

template "/etc/default/impalad" do
  mode 0755
  source "impala.start.erb"
  variables(:state_store => get_nodes_for("impala_statestore"))
end

%w{hbase-regionserver impala-server}.each do |svc|
  service svc do
    action [:enable, :start]
      subscribes :restart, "template[/etc/default/impalad]", :delayed
      subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
      subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
      subscribes :restart, "template[/etc/hadoop/conf/hbase-site.xml]", :delayed
  end
end



