include_recipe 'dpkg_autostart'
require "base64"

%w{hadoop-hdfs-namenode hadoop-hdfs-zkfc}.each do |pkg|
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
    command "chown -Rf hdfs:hdfs /disk/#{i}/dfs/"
    only_if { Etc.getpwuid(File.stat("/disk/#{i}/dfs/").uid).name != "hdfs" }
  end
end

if get_config("namenode_txn_fmt") then
  file "/tmp/nn_fmt.tgz" do
    user "hdfs"
    group "hdfs"
    user 0644
    content Base64.decode64(get_config("namenode_txn_fmt"))
  end
end

node[:bcpc][:hadoop][:mounts].each do |d|

  directory "/disk/#{d}/dfs/" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end

  bash "unpack nn fmt image" do
    user "hdfs"
    get_config("namenode_txn_fmt")
    code ["pushd /disk/#{d}/dfs/",
          "tar xzvf /tmp/nn_fmt.tgz",
          "popd"].join("\n")
    only_if { not get_config("namenode_txn_fmt").nil? and not Dir.entries("/disk/#{d}/dfs/nn").include?("current") }
  end
end

bash "hdfs namenode -bootstrapStandby" do
  user "hdfs"
  only_if { get_config("namenode_txn_fmt").nil? and not node[:bcpc][:hadoop][:mounts].all? { |d| Dir.entries("/disk/#{d}/dfs/nn/").include?("current") } }
end  

service "hadoop-hdfs-zkfc" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
end

service "hadoop-hdfs-namenode" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
end

