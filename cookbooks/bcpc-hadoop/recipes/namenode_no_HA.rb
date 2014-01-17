include_recipe 'dpkg_autostart'
require "base64"

%w{hadoop-hdfs-namenode}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs/nn" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end

  directory "/disk/#{i}/dfs/namedir" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
    recursive true
  end

  execute "fixup nn owner" do
    command "chown -Rf hdfs:hdfs /disk/#{i}/dfs"
    only_if { Etc.getpwuid(File.stat("/disk/#{i}/dfs/").uid).name != "hdfs" }
  end
end

bash "format namenode" do
  code "hdfs namenode -format -nonInteractive -force"
  user "hdfs"
  action :run
  creates "/disk/#{node[:bcpc][:hadoop][:mounts][0]}/dfs/nn/current/VERSION"
  not_if { File.exists?("/disk/#{node[:bcpc][:hadoop][:mounts][0]}/dfs/nn/current/VERSION")  }
end

service "hadoop-hdfs-namenode" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
end

###
# We only want to execute this once, as it is setup of dirs within HDFS.
# We'd prefer to do it after all nodes are members of the HDFS system
#
bash "create-hdfs-temp" do
  code "hadoop fs -mkdir /tmp; hadoop fs -chmod -R 1777 /tmp"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /tmp"
end

bash "create-hdfs-user" do
  code "hadoop fs -mkdir /user; hadoop fs -chmod -R 0755 /user"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user"
end

bash "create-hdfs-history" do
  code "hadoop fs -mkdir /user/history; hadoop fs -chmod -R 1777 /user/history; hadoop fs -chown yarn /user/history"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/history"
end

bash "create-hdfs-yarn-log" do
  code "hadoop fs -mkdir -p /var/log/hadoop-yarn; hadoop fs -chown yarn:mapred /var/log/hadoop-yarn"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /var/log/hadoop-yarn"
end

